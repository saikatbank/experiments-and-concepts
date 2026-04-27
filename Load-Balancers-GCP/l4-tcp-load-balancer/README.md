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

## 🚀 Getting Started

### Step 1 — Authenticate with GCP

```bash
gcloud auth application-default login
gcloud config set project <your-project-id>
```

### Step 2 — Configure Variables

```bash
cd l4-tcp-load-balancer
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
project          = "your-gcp-project-id"
region           = "us-central1"
zone             = "us-central1-c"
ssh_user         = "your-username"
ssh_pub_key_path = "~/.ssh/id_rsa.pub"
```

### Step 3 — Provision Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Note the outputs — you'll need the **LB external IP** for testing:

```bash
terraform output
```

### Step 4 — Configure the Ansible Inventory

Edit `ansible/inventory.gcp.yml` and update:
- `projects` → your GCP project ID
- `zones` → your target zone (must match `terraform.tfvars`)
- `compose.ansible_user` → your SSH username
- `compose.ansible_ssh_private_key_file` → path to your SSH private key

Verify that Ansible can discover your VMs:

```bash
ansible-inventory -i ansible/inventory.gcp.yml --list
```

### Step 5 — Configure Servers with Ansible

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventory.gcp.yml ansible/playbook.yml
```

> **Note:** `ANSIBLE_HOST_KEY_CHECKING=False` is needed to skip SSH host key verification on first connection. An `ansible.cfg` is included but may be ignored on Windows-mounted filesystems (WSL) due to world-writable directory permissions.

---

## 🧪 Testing the Load Balancer

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

Destroy all resources when done to avoid charges:

```bash
terraform destroy
```

---

## 📁 Project Structure

```
l4-tcp-load-balancer/
├── main.tf                        # All GCP resources (VMs, LB, firewall, etc.)
├── variables.tf                   # Input variable definitions
├── terraform.tfvars.example       # Template — copy to terraform.tfvars
├── .gitignore                     # Ignores .terraform/, *.tfstate, *.tfvars
├── ansible.cfg                    # Disables SSH host key checking
├── ansible/
│   ├── inventory.gcp.yml          # GCP dynamic inventory (auto-discovers VMs)
│   └── playbook.yml               # Installs & configures NGINX on VMs
└── README.md
```
