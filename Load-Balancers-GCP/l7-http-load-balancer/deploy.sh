#!/bin/bash
# ──────────────────────────────────────────────
# deploy.sh — One-command deploy for L7 HTTP Load Balancer experiment
# Provisions infrastructure (Terraform) + configures servers (Ansible)
# ──────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# ── Load config ──────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ config.env not found!"
    echo "   Run: cp config.env.example config.env"
    echo "   Then fill in your values."
    exit 1
fi

source "$CONFIG_FILE"

echo "📋 Config loaded:"
echo "   Project:  $GCP_PROJECT"
echo "   Region:   $GCP_REGION"
echo "   Zone:     $GCP_ZONE"
echo "   SSH User: $SSH_USER"
echo ""

# ── Generate terraform.tfvars ────────────────
cat > "$SCRIPT_DIR/terraform.tfvars" <<EOF
project          = "$GCP_PROJECT"
region           = "$GCP_REGION"
zone             = "$GCP_ZONE"
ssh_user         = "$SSH_USER"
ssh_pub_key_path = "$SSH_PUB_KEY_PATH"
EOF
echo "✅ Generated terraform.tfvars"

# ── Generate Ansible inventory ───────────────
cat > "$SCRIPT_DIR/ansible/inventory.gcp.yml" <<EOF
---
plugin: google.cloud.gcp_compute
projects:
  - "$GCP_PROJECT"
zones:
  - $GCP_ZONE
filters:
  - "tags.items:l7-http-lb"
auth_kind: application
hostvar_expressions:
  ansible_host: networkInterfaces[0].accessConfigs[0].natIP
keyed_groups:
  - key: tags['items'] | list
    prefix: tag
compose:
  ansible_user: "$SSH_USER"
  ansible_ssh_private_key_file: $SSH_PRIVATE_KEY_PATH
EOF
echo "✅ Generated ansible/inventory.gcp.yml"

# ── Terraform ────────────────────────────────
echo ""
echo "🏗️  Running Terraform..."
cd "$SCRIPT_DIR"
terraform init -input=false
terraform apply -auto-approve

echo ""
echo "⏳ Waiting 60s for VMs to boot..."
sleep 60

# ── Ansible ──────────────────────────────────
echo ""
echo "🔧 Running Ansible..."
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
    -i "$SCRIPT_DIR/ansible/inventory.gcp.yml" \
    "$SCRIPT_DIR/ansible/playbook.yml"

# ── Output ───────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo "✅ Deployment complete!"
echo ""
LB_IP=$(terraform output -raw lb_external_ip 2>/dev/null || echo "pending")
echo "🌐 Load Balancer IP: $LB_IP"
echo ""
echo "Test with:"
echo "  curl http://$LB_IP/"
echo "  curl http://$LB_IP/api"
echo "  curl http://$LB_IP/images"
echo ""
echo "Test request-level distribution:"
echo '  for i in {1..20}; do echo "Request $i:"; curl -s http://'"$LB_IP"'/api; echo ""; done'
echo "══════════════════════════════════════════"
