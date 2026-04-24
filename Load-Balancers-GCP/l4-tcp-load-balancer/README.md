# L4 TCP Load Balancer Experiment

## 📖 Overview
This experiment sets up a Layer 4 (Transport Layer) Load Balancer in GCP to demonstrate how it distributes traffic based on connections rather than requests.

## 🧪 Setup
- 2 VMs (`vm-a`, `vm-b`)
- NGINX running on both
- Backend = Unmanaged Instance Group
- LB = External TCP Load Balancer

## 🔍 Observations

When testing the Load Balancer:
- A simple browser refresh didn’t always switch servers.
- Parallel requests showed proper distribution across backends.

**👉 Learned:**
- L4 LB uses **connection-based routing**.
- It is NOT request-based.

## 🔁 Connection Behavior (Important)

### Problem:
Requests were always hitting the same VM.

### Reason:
- Connection reuse (keep-alive)
- Hash-based routing (client IP)

### Solution:
To force new connections and test distribution properly:

```bash
# Disable keep-alive
curl --no-keepalive http://<LB-IP>
```
Or use parallel requests:
```bash
seq 1 20 | xargs -n1 -P10 curl -s http://<LB-IP>
```
