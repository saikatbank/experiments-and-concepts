# GCP Load Balancers

## 📖 Overview
This concept focuses on exploring and testing various load balancing solutions available in Google Cloud Platform (GCP). The goal is to understand how traffic routing, health checks, and backend services function in different scenarios.

### 🧠 What is a Load Balancer?
A load balancer distributes incoming traffic across multiple backend servers to:
- Improve availability
- Prevent overload
- Increase scalability

### ⚙️ L4 vs L7 Load Balancer (Core Concept)

#### 🔹 Layer 4 (Transport Layer)
- Works on **TCP/UDP**
- Does NOT understand HTTP
- Distributes **connections**, not requests
> **Key Insight:** Same connection = same backend

#### 🔹 Layer 7 (Application Layer)
- Works on **HTTP/HTTPS**
- Understands URL, headers
- Can route based on: Path (`/api`, `/images`), Host, Headers
> **Key Insight:** Distributes **requests**, not just connections

### 🔐 Proxy Protocol (Key Concept)
**What it does:** Adds client info BEFORE actual request.
- **Without Proxy Protocol:** `GET / HTTP/1.1`
- **With Proxy Protocol:** `PROXY TCP4 <client-ip> <lb-ip> <client-port> <server-port>\nGET / HTTP/1.1`

#### ⚖️ When to Use Proxy Protocol
**✅ Use when:**
- Need real client IP at backend
- Logging / analytics
- Security / rate limiting

**❌ Avoid when:**
- Simplicity is preferred
- Backend not configured

## 🧪 Experiments Included

### 1. [L4 TCP Load Balancer](./l4-tcp-load-balancer/)
- **Goal:** Set up an external L4 Load Balancer and observe connection-based routing.

### 2. [Proxy Protocol Experiment](./proxy-protocol/)
- **Goal:** Enable proxy protocol and configure NGINX to accept real client IPs.

## ▶️ Getting Started
1. Navigate to the specific experiment folder.
2. Review the experiment's specific `README.md`.
3. Follow the instructions to replicate the experiment on your GCP environment.