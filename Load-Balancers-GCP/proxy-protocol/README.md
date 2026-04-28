# Proxy Protocol Experiment — GCP

## 📖 Overview

This experiment demonstrates how **Proxy Protocol** works with an L4 TCP Load Balancer on GCP. When enabled, the LB prepends a PROXY protocol header to every TCP connection, allowing the backend to see the **real client IP** instead of the load balancer's IP.

### Architecture

```
Client Request (TCP:80)
        │
        ▼
┌─────────────────────────┐
│  Global Forwarding Rule │  ← Static External IP
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  TCP Proxy (PROXY_V1)   │  ← Prepends: PROXY TCP4 <client-ip> <lb-ip> <port> <port>
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│   Backend Service       │  ← Health checks (TCP:80)
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  Unmanaged Instance     │
│       Group             │
├────────────┬────────────┤
│   VM-A     │   VM-B     │  ← NGINX with proxy_protocol (via Ansible)
└────────────┴────────────┘
```

### What You'll Learn

- How Proxy Protocol adds client info **before** the HTTP request
- How to configure NGINX to parse the `PROXY TCP4 ...` header
- How to extract the real client IP using `$proxy_protocol_addr`
- The difference between Proxy Protocol OFF vs ON

### Key Concept: What Proxy Protocol Does

```
Without Proxy Protocol:
  GET / HTTP/1.1

With Proxy Protocol (PROXY_V1):
  PROXY TCP4 <client-ip> <lb-ip> <client-port> <server-port>
  GET / HTTP/1.1
```

> **Important:** If Proxy Protocol is enabled on the LB but NGINX is NOT configured to handle it, you'll get `400 Bad Request` — because NGINX sees the `PROXY TCP4 ...` string instead of a valid HTTP request.

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
cd proxy-protocol
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
4. Run `ansible-playbook` to install and configure NGINX with Proxy Protocol
5. Print the Load Balancer IP

---

## 🧪 Testing

### Verify Proxy Protocol is Working

Use the LB IP printed by `deploy.sh`, or get it with:

```bash
terraform output lb_external_ip
```

```bash
curl http://<LB-IP>
```

Expected response:

```
Hello from pp-vm-a
Client IP: <your-real-public-ip>
```

If you see your **real public IP** (not the LB IP), Proxy Protocol is working correctly.

### Compare With and Without Proxy Protocol

SSH into a VM and inspect raw TCP traffic:

```bash
# SSH into a VM
gcloud compute ssh pp-vm-a --zone=us-central1-c

# Stop NGINX temporarily
sudo systemctl stop nginx

# Listen on port 80 to see raw traffic
sudo nc -l -p 80
```

Then `curl http://<LB-IP>` from your machine. You'll see:

```
PROXY TCP4 <client-ip> <lb-ip> <client-port> 80
GET / HTTP/1.1
...
```

### Test Traffic Distribution

```bash
for i in {1..20}; do
  echo "Request $i:"
  curl --no-keepalive http://<LB-IP>
  echo -e "\n"
done
```

---

## 🔍 Key Observations

| Scenario | What Backend Sees |
|----------|-------------------|
| Proxy Protocol **OFF** | Backend sees LB's IP as the client |
| Proxy Protocol **ON** (NGINX not configured) | `400 Bad Request` — NGINX can't parse the PROXY header |
| Proxy Protocol **ON** (NGINX configured) | Backend sees **real client IP** via `$proxy_protocol_addr` |

### What the Ansible Playbook Configures

The NGINX config deployed by Ansible includes three critical directives:

```nginx
# 1. Tell NGINX to expect proxy protocol on this listener
listen 80 proxy_protocol;

# 2. Trust the proxy protocol header from any source
set_real_ip_from 0.0.0.0/0;

# 3. Use the proxy protocol header to extract the real client IP
real_ip_header proxy_protocol;
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
proxy-protocol/
├── config.env.example             # 👈 Single config — copy to config.env
├── deploy.sh                      # One-command deploy (Terraform + Ansible)
├── destroy.sh                     # One-command teardown
├── main.tf                        # GCP resources (VMs, LB with PROXY_V1, firewall)
├── variables.tf                   # Input variable definitions
├── terraform.tfvars.example       # (Alternative) manual Terraform config
├── .gitignore                     # Ignores generated files
├── ansible.cfg                    # Disables SSH host key checking
├── ansible/
│   └── playbook.yml               # Installs NGINX with proxy_protocol support
└── README.md
```

> **Note:** `terraform.tfvars` and `ansible/inventory.gcp.yml` are **auto-generated** by `deploy.sh` — no need to create or edit them manually.
