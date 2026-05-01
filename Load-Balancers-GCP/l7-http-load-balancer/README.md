# L7 HTTP Load Balancer — GCP

## 📖 Overview

This experiment sets up a **Global HTTP(S) Layer 7 Load Balancer** on Google Cloud Platform using **Terraform** for infrastructure provisioning and **Ansible** for server configuration.

It demonstrates **path-based routing to separate backend services** — the core L7 feature that L4 load balancers cannot do.

### Architecture

```
Client Request (HTTP:80)
        │
        ▼
┌─────────────────────────┐
│  Global Forwarding Rule │  ← Static External IP (port 80)
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│   Target HTTP Proxy     │  ← Terminates HTTP, forwards to URL Map
└────────────┬────────────┘
             ▼
┌─────────────────────────────────────────┐
│              URL Map                     │
│                                          │
│  /api, /images, /*  ──→  Web Backend     │
│  /db, /db/*         ──→  DB Backend      │
└─────────┬──────────────────┬─────────────┘
          ▼                  ▼
┌──────────────────┐  ┌──────────────────┐
│  Web Backend Svc │  │  DB Backend Svc  │
│  (HTTP, port 80) │  │  (HTTP, port 80) │
└────────┬─────────┘  └────────┬─────────┘
         ▼                     ▼
┌──────────────────┐  ┌──────────────────┐
│  Web Group       │  │  DB Group        │
├────────┬─────────┤  │                  │
│ VM-A   │  VM-B   │  │     VM-C         │
│ (Web)  │  (Web)  │  │     (DB)         │
└────────┴─────────┘  └──────────────────┘
```

### What You'll Learn

- L7 LB distributes **requests**, not connections (unlike L4)
- How URL Maps route traffic based on URL path to **different backend services**
- How separate backend services map to separate instance groups
- The difference between L4 (TCP Proxy) and L7 (HTTP Proxy + URL Map)
- How to use Ansible with multiple VM roles using GCP tags

### Key Concept: L4 vs L7

| Feature | L4 (Experiments 1 & 2) | L7 (This Experiment) |
|---------|----------------------|---------------------|
| Layer | Transport (TCP/UDP) | Application (HTTP/HTTPS) |
| Distributes | **Connections** | **Requests** |
| Understands | TCP packets | HTTP headers, URLs, paths |
| Routing | Hash-based (client IP) | URL path, host, headers |
| GCP Component | TCP Proxy | HTTP Proxy + URL Map |
| Backend Services | 1 (all traffic) | **Multiple** (per path) |

> **Key Insight:** With L7, each URL path can route to a completely **different backend service** backed by different VMs. In this experiment, `/api` and `/images` go to web VMs (A & B), while `/db` goes to a separate DB VM (C).

---

## 🛠️ Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.0 | Infrastructure provisioning |
| [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) | ≥ 2.12 | Server configuration |
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | Latest | GCP authentication |
| SSH key pair | — | VM access for Ansible |

### Ansible Dependencies

```bash
pip install google-auth requests
ansible-galaxy collection install google.cloud
```

---

## 🚀 Quick Start (One Command)

### Step 1 — Authenticate with GCP

```bash
gcloud auth application-default login
gcloud config set project <your-project-id>
```

### Step 2 — Configure

```bash
cd l7-http-load-balancer
cp config.env.example config.env
```

Edit `config.env` with your values:

```bash
GCP_PROJECT="your-gcp-project-id"
GCP_REGION="us-central1"
GCP_ZONE="us-central1-c"
SSH_USER="your-username"
SSH_PUB_KEY_PATH="~/.ssh/id_rsa.pub"
SSH_PRIVATE_KEY_PATH="~/.ssh/id_rsa"
```

> **Note:** This is the **only file you need to edit**. The deploy script auto-generates `terraform.tfvars` and `ansible/inventory.gcp.yml` from this config.

### Step 3 — Deploy Everything

```bash
chmod +x deploy.sh destroy.sh
./deploy.sh
```

This single command will:
1. Generate `terraform.tfvars` and Ansible inventory from `config.env`
2. Run `terraform apply` to provision all GCP resources (3 VMs, 2 backend services, URL Map)
3. Wait for VMs to boot
4. Run `ansible-playbook` to configure NGINX:
   - **Web VMs (A, B):** `/api` (JSON), `/images` (text), `/` (default)
   - **DB VM (C):** `/db` (JSON with DB status)
5. Print the Load Balancer IP and test commands

---

## 🧪 Testing

### Get the Load Balancer IP

Use the IP printed by `deploy.sh`, or get it with:

```bash
terraform output lb_external_ip
```

> **Note:** L7 LBs on GCP can take **5-10 minutes** after deployment to start serving traffic. If you get `502 Bad Gateway`, wait a few minutes and retry.

### Test Path-Based Routing

#### Default Path (`/`) → Web Backend (VM-A or VM-B)

```bash
curl http://<LB-IP>/
```

Expected response:
```
Hello from l7-vm-a
Path: /
Served via L7 HTTP Load Balancer
```

#### API Path (`/api`) → Web Backend (VM-A or VM-B)

```bash
curl http://<LB-IP>/api
```

Expected response (JSON):
```json
{"server": "l7-vm-b", "path": "/api", "message": "API response from L7 backend"}
```

#### Images Path (`/images`) → Web Backend (VM-A or VM-B)

```bash
curl http://<LB-IP>/images
```

Expected response:
```
Image server: l7-vm-a
Path: /images
This would serve static images in production.
```

#### DB Path (`/db`) → DB Backend (VM-C only)

```bash
curl http://<LB-IP>/db
```

Expected response (JSON — always from VM-C):
```json
{"server": "l7-vm-c", "path": "/db", "service": "database", "status": "healthy", "engine": "PostgreSQL 16"}
```

> **Key Observation:** `/db` will **always** return `l7-vm-c` because it routes to the DB backend service which only has VM-C. This proves that the URL Map routes different paths to completely different backend services.

### Verify Request-Level Distribution (L7 Key Learning)

Unlike L4, the L7 LB distributes **individual requests** across backends. Run multiple requests to the web paths:

```bash
for i in {1..20}; do
  echo "Request $i:"
  curl -s http://<LB-IP>/api
  echo ""
done
```

You should see responses from **both** `l7-vm-a` and `l7-vm-b`.

Now do the same for the DB path:

```bash
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://<LB-IP>/db
  echo ""
done
```

You should see responses **only** from `l7-vm-c` — proving the URL Map routes `/db` to a completely separate backend.

### Compare with L4 Behavior

| Behavior | L4 (Experiment 1) | L7 (This Experiment) |
|----------|-------------------|---------------------|
| `curl` in a loop | May hit **same** VM (connection reuse) | Hits **both** VMs (request distribution) |
| `--no-keepalive` needed? | **Yes** — to force new connections | **No** — each request is independently routed |
| Path-based routing | ❌ Not possible | ✅ `/api`, `/images` → Web; `/db` → DB |
| Multiple backends | ❌ Single backend | ✅ Web Backend + DB Backend |
| Browser refresh | Same server (keep-alive) | May alternate between servers |

---

## 🔍 Key Observations

1. **Separate Backend Services**: `/api` and `/images` go to the Web Backend (VM-A, VM-B), while `/db` goes to the DB Backend (VM-C) — different paths, different servers
2. **Request-Level Distribution**: Web paths show responses from different VMs; DB path always shows VM-C
3. **URL Map Routing**: The URL Map is the L7 brain — it decides which backend service handles each request based on the URL path
4. **HTTP Health Checks**: Both backend services share the same health check (GET `/` on port 80)
5. **GCP Health Check IPs**: A dedicated firewall rule allows GCP health check probes from `35.191.0.0/16` and `130.211.0.0/22`
6. **Warm-up Time**: L7 LBs take longer to start (5-10 min) compared to L4 — you may see `502` errors initially

### GCP Resource Mapping

| Path | URL Map Rule | Backend Service | Instance Group | VM(s) |
|------|-------------|-----------------|----------------|-------|
| `/api`, `/api/*` | `allpaths` | `l7-web-backend-service` | `l7-web-group` | VM-A, VM-B |
| `/images`, `/images/*` | `allpaths` | `l7-web-backend-service` | `l7-web-group` | VM-A, VM-B |
| `/db`, `/db/*` | `allpaths` | `l7-db-backend-service` | `l7-db-group` | VM-C |
| `/*` (default) | `allpaths` | `l7-web-backend-service` | `l7-web-group` | VM-A, VM-B |

### Tagging Strategy

| Tag | Applied To | Purpose |
|-----|-----------|---------|
| `l7-http-lb` | All VMs (A, B, C) | Firewall rules (HTTP, SSH, health check) |
| `l7-web` | VM-A, VM-B | Ansible targeting — web NGINX config |
| `l7-db` | VM-C | Ansible targeting — DB NGINX config |

### What the Ansible Playbook Configures

**Play 1 — Web Servers (VM-A, VM-B):**
```nginx
location /api    { return 200 '{"server":"$hostname","path":"/api",...}'; }
location /images { return 200 "Image server: $hostname\n..."; }
location /       { return 200 "Hello from $hostname\n..."; }
```

**Play 2 — DB Server (VM-C):**
```nginx
location /db { return 200 '{"server":"$hostname","service":"database","status":"healthy",...}'; }
location /   { return 200 "DB Server: $hostname\n..."; }
```

---

## 🧹 Cleanup

Destroy all resources with one command:

```bash
./destroy.sh
```

---

## 📁 Project Structure

```
l7-http-load-balancer/
├── config.env.example             # 👈 Single config — copy to config.env
├── deploy.sh                      # One-command deploy (Terraform + Ansible)
├── destroy.sh                     # One-command teardown
├── main.tf                        # GCP resources (3 VMs, 2 backends, URL Map, firewall)
├── variables.tf                   # Input variable definitions
├── terraform.tfvars.example       # (Alternative) manual Terraform config
├── .gitignore                     # Ignores generated files
├── ansible.cfg                    # Disables SSH host key checking
├── ansible/
│   └── playbook.yml               # 2 plays: Web servers + DB server NGINX configs
└── README.md
```

> **Note:** `terraform.tfvars` and `ansible/inventory.gcp.yml` are **auto-generated** by `deploy.sh` — no need to create or edit them manually.
