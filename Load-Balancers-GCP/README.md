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

## 🧪 GCP Load Balancer Experiments Roadmap

| #  | Experiment Name              | LB Type               | Goal                                     | What You Configure                             | What to Test                    | Key Learning                                  |
| -- | ---------------------------- | --------------------- | ---------------------------------------- | ---------------------------------------------- | ------------------------------- | --------------------------------------------- |
| 1  | [L4 Load Balancer (Done)](./l4-tcp-load-balancer/) | External TCP/UDP (L4) | Understand basic load distribution       | 2 VMs + unmanaged instance group + TCP LB      | Multiple curl requests          | L4 distributes **connections**, not requests  |
| 2  | HTTP Load Balancer           | Global HTTP(S) (L7)   | Understand request-based routing         | Backend services + URL map (`/api`, `/images`) | Hit different paths             | L7 distributes **requests**, supports routing |
| 3  | Header Inspection            | HTTP(S) LB (L7)       | Understand client IP handling            | Enable LB + check headers                      | `curl -v` and inspect headers   | `X-Forwarded-For` carries real client IP      |
| 4  | Internal Load Balancer       | Internal HTTP(S)      | Understand private service communication | Private VMs + internal LB                      | Curl from another VM            | Microservices communicate via internal LB     |
| 5  | Health Check Failure         | Any LB                | Understand failover                      | Stop nginx on one VM                           | Observe traffic shift           | LB removes unhealthy instances automatically  |
| 6  | Session Affinity             | HTTP(S) LB            | Understand sticky sessions               | Enable session affinity                        | Repeated curl/browser requests  | Same client → same backend                    |
| 7  | Managed Instance Group (MIG) | Any LB + MIG          | Understand autoscaling                   | Instance template + MIG + LB                   | Generate load (ab tool)         | Infra scales automatically                    |
| 8  | Load Testing                 | Any LB                | Observe behavior under load              | Use `ab` or parallel curl                      | High concurrency requests       | Traffic distribution patterns                 |
| 9  | Logging & Monitoring         | Any LB                | Understand observability                 | Enable logging in LB                           | Check logs/metrics              | Debugging real traffic                        |
| 10 | Multi-region LB              | Global HTTP(S)        | Understand global routing                | Backends in multiple regions                   | Access from different locations | Latency-based routing (Anycast)               |
| 11 | [Proxy Protocol vs XFF (Done)](./proxy-protocol/) | L4 vs L7              | Compare client IP handling               | Proxy Protocol (L4) vs headers (L7)            | Inspect logs                    | Different ways to pass client IP              |
| 12 | SSL Termination              | HTTP(S) LB            | Understand HTTPS handling                | Add HTTPS frontend + cert                      | Access via https                | LB handles TLS, backend stays HTTP            |

---

## ▶️ Getting Started
1. Navigate to the specific experiment folder.
2. Review the experiment's specific `README.md`.
3. Follow the instructions to replicate the experiment on your GCP environment.