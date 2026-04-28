# L4 TCP Load Balancer — GCP

## 📖 Overview

This experiment sets up an **External L4 (Layer 4) TCP Load Balancer** on Google Cloud Platform using **Terraform** for infrastructure provisioning and **Ansible** for server configuration.

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
│     TCP Proxy           │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│   Backend Service       │  ← Health checks (HTTP:80)
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  Unmanaged Instance     │
│       Group             │
├────────────┬────────────┤
│   VM-A     │   VM-B     │  ← NGINX (installed via Ansible)
└────────────┴────────────┘
```

### What You'll Learn
- L4 LB distributes **connections**, not individual HTTP requests
- Same TCP connection = same backend (connection-based routing)
- How to use Ansible dynamic inventory with GCP

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
cd l4-tcp-load-balancer
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
4. Run `ansible-playbook` to install and configure NGINX
5. Print the Load Balancer IP

---

## 🧪 Testing the Load Balancer

Use the LB IP printed by `deploy.sh`, or get it with:

```bash
terraform output lb_external_ip
```

### Basic Request

```bash
curl http://<LB-IP>
```

### Verify Traffic Distribution

L4 load balancers route by **connection**, not by request. To see traffic distributed across backends, force new connections:

```bash
for i in {1..20}; do
  echo "Request $i:"
  curl --no-keepalive http://<LB-IP>
  echo -e "\n"
done
```

### 🔍 Key Observations
- A simple browser refresh may **not** switch servers (connection reuse / keep-alive)
- Using `--no-keepalive` forces a new TCP connection per request
- L4 LB uses hash-based routing (client IP) — you'll see both `vm-a` and `vm-b` responses

---

## 🧹 Cleanup

Destroy all resources with one command:

```bash
./destroy.sh
```

---

## 📁 Project Structure

```
l4-tcp-load-balancer/
├── config.env.example             # 👈 Single config — copy to config.env
├── deploy.sh                      # One-command deploy (Terraform + Ansible)
├── destroy.sh                     # One-command teardown
├── main.tf                        # All GCP resources (VMs, LB, firewall, etc.)
├── variables.tf                   # Input variable definitions
├── terraform.tfvars.example       # (Alternative) manual Terraform config
├── .gitignore                     # Ignores generated files
├── ansible.cfg                    # Disables SSH host key checking
├── ansible/
│   └── playbook.yml               # Installs & configures NGINX on VMs
└── README.md
```

> **Note:** `terraform.tfvars` and `ansible/inventory.gcp.yml` are **auto-generated** by `deploy.sh` — no need to create or edit them manually.
