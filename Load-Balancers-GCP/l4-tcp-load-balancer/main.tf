# ╔══════════════════════════════════════════════════════════════╗
# ║  L4 TCP Load Balancer — GCP                                 ║
# ║                                                              ║
# ║  Architecture:                                               ║
# ║  Client → Forwarding Rule → TCP Proxy → Backend Service     ║
# ║           → Instance Group → VMs (nginx via Ansible)         ║
# ╚══════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────
# Provider
# ──────────────────────────────────────────────

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# ──────────────────────────────────────────────
# Firewall Rules
# ──────────────────────────────────────────────

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["nginx"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["nginx"]
}

# ──────────────────────────────────────────────
# Compute Instances
# ──────────────────────────────────────────────

resource "google_compute_instance" "vm_a" {
  name         = "vm-a"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["nginx"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {} # Ephemeral public IP
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_pub_key_path)}"
  }
}

resource "google_compute_instance" "vm_b" {
  name         = "vm-b"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["nginx"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {} # Ephemeral public IP
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_pub_key_path)}"
  }
}

# ──────────────────────────────────────────────
# Unmanaged Instance Group
# ──────────────────────────────────────────────

resource "google_compute_instance_group" "web_group" {
  name      = "web-group"
  zone      = var.zone
  instances = [
    google_compute_instance.vm_a.self_link,
    google_compute_instance.vm_b.self_link,
  ]

  named_port {
    name = "http"
    port = 80
  }
}

# ──────────────────────────────────────────────
# Health Check
# ──────────────────────────────────────────────

resource "google_compute_health_check" "http_health_check" {
  name                = "http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# ──────────────────────────────────────────────
# Backend Service
# ──────────────────────────────────────────────

resource "google_compute_backend_service" "web_backend_service" {
  name          = "web-backend-service"
  protocol      = "TCP"
  health_checks = [google_compute_health_check.http_health_check.id]

  backend {
    group = google_compute_instance_group.web_group.id
  }
}

# ──────────────────────────────────────────────
# TCP Proxy
# ──────────────────────────────────────────────

resource "google_compute_target_tcp_proxy" "target_tcp_proxy" {
  name            = "target-tcp-proxy"
  backend_service = google_compute_backend_service.web_backend_service.id
}

# ──────────────────────────────────────────────
# External IP + Global Forwarding Rule
# ──────────────────────────────────────────────

resource "google_compute_global_address" "lb_external_ip" {
  name = "l4-tcp-lb-external-ip"
}

resource "google_compute_global_forwarding_rule" "l4_tcp_forwarding_rule" {
  name                  = "l4-tcp-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_tcp_proxy.target_tcp_proxy.id
  ip_address            = google_compute_global_address.lb_external_ip.address
  load_balancing_scheme = "EXTERNAL"
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "lb_external_ip" {
  description = "External IP of the L4 TCP Load Balancer"
  value       = google_compute_global_address.lb_external_ip.address
}

output "vm_a_external_ip" {
  description = "External IP of VM A"
  value       = google_compute_instance.vm_a.network_interface[0].access_config[0].nat_ip
}

output "vm_b_external_ip" {
  description = "External IP of VM B"
  value       = google_compute_instance.vm_b.network_interface[0].access_config[0].nat_ip
}