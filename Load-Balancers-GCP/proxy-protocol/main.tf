# ╔══════════════════════════════════════════════════════════════╗
# ║  Proxy Protocol Experiment — GCP                            ║
# ║                                                              ║
# ║  Architecture:                                               ║
# ║  Client → Forwarding Rule → TCP Proxy (PROXY_V1)            ║
# ║           → Backend Service → Instance Group                 ║
# ║           → VMs (NGINX with proxy_protocol via Ansible)      ║
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
  name    = "pp-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["proxy-protocol"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "pp-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["proxy-protocol"]
}

# ──────────────────────────────────────────────
# Compute Instances
# ──────────────────────────────────────────────

resource "google_compute_instance" "vm_a" {
  name         = "pp-vm-a"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["proxy-protocol"]

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
  name         = "pp-vm-b"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["proxy-protocol"]

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
  name      = "pp-web-group"
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

resource "google_compute_health_check" "tcp_health_check" {
  name                = "pp-tcp-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port = 80
  }
}

# ──────────────────────────────────────────────
# Backend Service
# ──────────────────────────────────────────────

resource "google_compute_backend_service" "web_backend_service" {
  name          = "pp-web-backend-service"
  protocol      = "TCP"
  health_checks = [google_compute_health_check.tcp_health_check.id]

  backend {
    group = google_compute_instance_group.web_group.id
  }
}

# ──────────────────────────────────────────────
# TCP Proxy (with Proxy Protocol ENABLED)
# ──────────────────────────────────────────────

resource "google_compute_target_tcp_proxy" "target_tcp_proxy" {
  name            = "pp-target-tcp-proxy"
  backend_service = google_compute_backend_service.web_backend_service.id
  proxy_header    = "PROXY_V1"
}

# ──────────────────────────────────────────────
# External IP + Global Forwarding Rule
# ──────────────────────────────────────────────

resource "google_compute_global_address" "lb_external_ip" {
  name = "pp-lb-external-ip"
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "pp-forwarding-rule"
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
  description = "External IP of the Load Balancer (with Proxy Protocol)"
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
