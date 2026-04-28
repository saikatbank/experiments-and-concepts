#!/bin/bash
# ──────────────────────────────────────────────
# destroy.sh — One-command teardown
# Destroys all infrastructure provisioned by Terraform.
# ──────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# ── Load config ──────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ config.env not found!"
    exit 1
fi

source "$CONFIG_FILE"

echo "⚠️  This will destroy ALL resources in project: $GCP_PROJECT"
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# ── Terraform Destroy ────────────────────────
cd "$SCRIPT_DIR"
terraform destroy -auto-approve

echo ""
echo "══════════════════════════════════════════"
echo "✅ All resources destroyed."
echo "══════════════════════════════════════════"
