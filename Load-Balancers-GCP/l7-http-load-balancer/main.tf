# ╔══════════════════════════════════════════════════════════════╗
# ║  L7 HTTP Load Balancer — GCP                                ║
# ║                                                              ║
# ║  Architecture:                                               ║
# ║  Client → Forwarding Rule → HTTP Proxy → URL Map            ║
# ║           ├─ /api, /images, /* → Web Backend → Web Group     ║
# ║           │                      (VM-A, VM-B)                ║
# ║           └─ /db, /db/*       → DB Backend  → DB Group      ║
# ║                                  (VM-C)                      ║
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
  name    = "l7-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["l7-http-lb"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "l7-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["l7-http-lb"]
}

# ──────────────────────────────────────────────
# Allow GCP Health Check Probes
# GCP health checkers come from these IP ranges:
#   35.191.0.0/16 and 130.211.0.0/22
# ──────────────────────────────────────────────

resource "google_compute_firewall" "allow_health_check" {
  name    = "l7-allow-health-check"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["l7-http-lb"]
}

# ──────────────────────────────────────────────
# Compute Instances
# ──────────────────────────────────────────────

resource "google_compute_instance" "vm_a" {
  name         = "l7-vm-a"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["l7-http-lb", "l7-web"]

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
  name         = "l7-vm-b"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["l7-http-lb", "l7-web"]

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

resource "google_compute_instance" "vm_c" {
  name         = "l7-vm-c"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["l7-http-lb", "l7-db"]

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
# Unmanaged Instance Groups
# ──────────────────────────────────────────────

resource "google_compute_instance_group" "web_group" {
  name      = "l7-web-group"
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

resource "google_compute_instance_group" "db_group" {
  name      = "l7-db-group"
  zone      = var.zone
  instances = [
    google_compute_instance.vm_c.self_link,
  ]

  named_port {
    name = "http"
    port = 80
  }
}

# ──────────────────────────────────────────────
# Health Check (HTTP — L7 uses HTTP health checks)
# ──────────────────────────────────────────────

resource "google_compute_health_check" "http_health_check" {
  name                = "l7-http-health-check"
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
# Backend Services (HTTP protocol for L7)
# ──────────────────────────────────────────────

resource "google_compute_backend_service" "web_backend_service" {
  name                  = "l7-web-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.http_health_check.id]
  timeout_sec           = 30

  backend {
    group           = google_compute_instance_group.web_group.id
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
}

resource "google_compute_backend_service" "db_backend_service" {
  name                  = "l7-db-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.http_health_check.id]
  timeout_sec           = 30

  backend {
    group           = google_compute_instance_group.db_group.id
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
}

# ──────────────────────────────────────────────
# URL Map (path-based routing — the L7 key feature)
# ──────────────────────────────────────────────

resource "google_compute_url_map" "url_map" {
  name            = "l7-url-map"
  default_service = google_compute_backend_service.web_backend_service.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.web_backend_service.id

    path_rule {
      paths   = ["/api", "/api/*"]
      service = google_compute_backend_service.web_backend_service.id
    }

    path_rule {
      paths   = ["/images", "/images/*"]
      service = google_compute_backend_service.web_backend_service.id
    }

    path_rule {
      paths   = ["/db", "/db/*"]
      service = google_compute_backend_service.db_backend_service.id
    }
  }
}

# ──────────────────────────────────────────────
# Target HTTP Proxy (replaces TCP Proxy from L4)
# ──────────────────────────────────────────────

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "l7-target-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

# ──────────────────────────────────────────────
# External IP + Global Forwarding Rule
# ──────────────────────────────────────────────

resource "google_compute_global_address" "lb_external_ip" {
  name = "l7-lb-external-ip"
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "l7-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  ip_address            = google_compute_global_address.lb_external_ip.address
  load_balancing_scheme = "EXTERNAL"
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "lb_external_ip" {
  description = "External IP of the L7 HTTP Load Balancer"
  value       = google_compute_global_address.lb_external_ip.address
}

output "vm_a_external_ip" {
  description = "External IP of VM A"
  value       = google_compute_instance.vm_a.network_interface[0].access_config[0].nat_ip
}

output "vm_b_external_ip" {
  description = "External IP of VM B (Web)"
  value       = google_compute_instance.vm_b.network_interface[0].access_config[0].nat_ip
}

output "vm_c_external_ip" {
  description = "External IP of VM C (DB)"
  value       = google_compute_instance.vm_c.network_interface[0].access_config[0].nat_ip
}
