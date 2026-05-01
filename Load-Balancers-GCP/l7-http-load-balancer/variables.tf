# ──────────────────────────────────────────────
# Project & Region
# ──────────────────────────────────────────────

variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for VM instances"
  type        = string
  default     = "us-central1-c"
}

# ──────────────────────────────────────────────
# SSH Configuration (for Ansible access)
# ──────────────────────────────────────────────

variable "ssh_user" {
  description = "SSH username to provision on VMs"
  type        = string
}

variable "ssh_pub_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
