# Proxy Protocol Experiment

## 📖 Overview
This experiment demonstrates how to enable and handle Proxy Protocol with an L4 Load Balancer. Since an L4 LB does not terminate HTTP, the backend needs to extract the real client IP.

## 🧪 Experiment Setup

- Stop NGINX on backend VMs.
- Run a persistent listener to inspect incoming raw TCP traffic:
  ```bash
  while true; do sudo nc -l -p 80; done
  ```

## 🔍 Observations

**Proxy OFF:**
```text
GET / HTTP/1.1
```

**Proxy ON:**
```text
PROXY TCP4 <client-ip> <lb-ip> <client-port> <server-port>
GET / HTTP/1.1
```

## 💥 Fixing NGINX (400 Bad Request)

When Proxy Protocol is enabled, NGINX breaks because it expects a standard HTTP request, but it receives the `PROXY TCP4 ...` string first, resulting in a `400 Bad Request`.

### 🔹 Step 1: Enable Proxy Protocol on listener
Edit the NGINX configuration:
```bash
sudo nano /etc/nginx/sites-enabled/default
```
Change the listen directive:
```nginx
# From:
listen 80;
# To:
listen 80 proxy_protocol;
```

### 🔹 Step 2: Accept real client IP
Add the following inside the `server` block to tell NGINX to trust the proxy protocol header and extract the real client IP:
```nginx
set_real_ip_from 0.0.0.0/0;
real_ip_header proxy_protocol;
```

## 🔥 Real-World Insight Summary

| Scenario | Behavior |
| --- | --- |
| L4 LB | Connection-based |
| L7 LB | Request-based |
| Proxy Protocol OFF | Backend sees LB IP |
| Proxy Protocol ON | Backend sees real client IP |
