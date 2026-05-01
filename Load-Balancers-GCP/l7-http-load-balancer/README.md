# L7 HTTP Load Balancer — GCP

## 📖 Overview

This experiment sets up a **Global HTTP(S) Layer 7 Load Balancer** on Google Cloud Platform using **Terraform** for infrastructure provisioning and **Ansible** for server configuration.

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
┌─────────────────────────┐
│        URL Map          │  ← Path-based routing:
│  /api     → backend-svc │     Route by URL path
│  /images  → backend-svc │
│  /*       → backend-svc │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│   Backend Service       │  ← HTTP health checks (port 80, path /)
│   (protocol: HTTP)      │     Balancing mode: UTILIZATION
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  Unmanaged Instance     │
│       Group             │
├────────────┬────────────┤
│   VM-A     │   VM-B     │  ← NGINX with path-based responses (via Ansible)
└────────────┴────────────┘
```

### What You'll Learn

- L7 LB distributes **requests**, not connections (unlike L4)
- How URL Maps route traffic based on URL path
- The difference between L4 (TCP Proxy) and L7 (HTTP Proxy + URL Map)
- How Backend Services work with HTTP protocol and utilization-based balancing

### Key Concept: L4 vs L7

| Feature | L4 (Experiments 1 & 2) | L7 (This Experiment) |
|---------|----------------------|---------------------|
| Layer | Transport (TCP/UDP) | Application (HTTP/HTTPS) |
| Distributes | **Connections** | **Requests** |
| Understands | TCP packets | HTTP headers, URLs, paths |
| Routing | Hash-based (client IP) | URL path, host, headers |
| GCP Component | TCP Proxy | HTTP Proxy + URL Map |

> **Key Insight:** With L7, each individual HTTP request can go to a different backend — even within the same TCP connection. This is fundamentally different from L4, where the entire connection sticks to one backend.

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
2. Run `terraform apply` to provision all GCP resources
3. Wait for VMs to boot
4. Run `ansible-playbook` to install and configure NGINX with path-based responses
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

#### Default Path (`/`)

```bash
curl http://<LB-IP>/
```

Expected response:
```
Hello from l7-vm-a
Path: /
Served via L7 HTTP Load Balancer
```

#### API Path (`/api`)

```bash
curl http://<LB-IP>/api
```

Expected response (JSON):
```json
{"server": "l7-vm-b", "path": "/api", "message": "API response from L7 backend"}
```

#### Images Path (`/images`)

```bash
curl http://<LB-IP>/images
```

Expected response:
```
Image server: l7-vm-a
Path: /images
This would serve static images in production.
```

### Verify Request-Level Distribution (L7 Key Learning)

Unlike L4, the L7 LB distributes **individual requests** across backends. Run multiple requests to see both VMs respond:

```bash
for i in {1..20}; do
  echo "Request $i:"
  curl -s http://<LB-IP>/api
  echo ""
done
```

You should see responses from **both** `l7-vm-a` and `l7-vm-b` — even without `--no-keepalive`. This proves that L7 distributes requests, not connections.

### Compare with L4 Behavior

| Behavior | L4 (Experiment 1) | L7 (This Experiment) |
|----------|-------------------|---------------------|
| `curl` in a loop | May hit **same** VM (connection reuse) | Hits **both** VMs (request distribution) |
| `--no-keepalive` needed? | **Yes** — to force new connections | **No** — each request is independently routed |
| Path-based routing | ❌ Not possible | ✅ `/api`, `/images`, `/` all work |
| Browser refresh | Same server (keep-alive) | May alternate between servers |

---

## 🔍 Key Observations

1. **Request-Level Distribution**: Unlike L4, you'll see responses from different VMs even within the same keep-alive connection
2. **URL Map Routing**: The URL Map defines which paths go to which backend service (in this experiment, all paths use the same backend, but each returns different content)
3. **HTTP Health Checks**: The L7 LB uses HTTP health checks (GET `/` on port 80), not TCP health checks like L4
4. **GCP Health Check IPs**: A dedicated firewall rule allows GCP health check probes from `35.191.0.0/16` and `130.211.0.0/22`
5. **Warm-up Time**: L7 LBs take longer to start (5-10 min) compared to L4 — you may see `502` errors initially

### What the Ansible Playbook Configures

NGINX is configured with three location blocks:

```nginx
# API endpoint — returns JSON with hostname
location /api {
    default_type application/json;
    return 200 '{"server": "$hostname", "path": "/api", ...}';
}

# Images endpoint — returns plain text with hostname
location /images {
    default_type text/plain;
    return 200 "Image server: $hostname\n...";
}

# Default — returns plain text with hostname and request URI
location / {
    default_type text/plain;
    return 200 "Hello from $hostname\n...";
}
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
├── main.tf                        # GCP resources (VMs, L7 LB, URL Map, firewall)
├── variables.tf                   # Input variable definitions
├── terraform.tfvars.example       # (Alternative) manual Terraform config
├── .gitignore                     # Ignores generated files
├── ansible.cfg                    # Disables SSH host key checking
├── ansible/
│   └── playbook.yml               # Installs NGINX with path-based responses
└── README.md
```

> **Note:** `terraform.tfvars` and `ansible/inventory.gcp.yml` are **auto-generated** by `deploy.sh` — no need to create or edit them manually.
