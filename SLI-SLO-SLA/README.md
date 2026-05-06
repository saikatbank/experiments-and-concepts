# SLI vs SLO vs SLA

## 📖 Overview

| Term | Meaning | Audience |
|------|---------|----------|
| SLI | What is **measured** | Engineering |
| SLO | **Target** for the metric | Internal teams |
| SLA | Official **customer promise** | Customers |

---

## 📏 SLI (Service Level Indicator)

A **measurement metric** to evaluate system reliability.

**Common SLIs:** Availability, Latency, Error Rate, Throughput, Request Success Rate

**Formula Example:**
```
Availability = Successful Requests / Total Requests
```

---

## 🎯 SLO (Service Level Objective)

A **target value** set for an SLI. Defines expected reliability.

| Example SLO | Metric |
|-------------|--------|
| 99.9% uptime/month | Availability |
| 95% requests < 200ms | Latency |
| Error rate < 0.1% | Error Rate |

> **Key Insight:** SLO helps prioritize stability vs feature delivery

---

## 📝 SLA (Service Level Agreement)

A **formal commitment** to customers. Includes guaranteed performance + compensation if violated.

- 99.9% guaranteed uptime
- Service credits if downtime exceeds agreed limit

> **Key Insight:** SLO is usually **higher** than SLA (safety margin)
> - Internal SLO = 99.99%
> - External SLA = 99.9%

---

## 🔥 Error Budget

Allowed failure amount based on SLO.

**If SLO = 99.9% uptime → Allowed downtime = 0.1% → ~43.2 min/month**

**Why it matters:**
- Controls release velocity
- Balances innovation and reliability
- Core to Google SRE practices

---

## 📊 Availability Table

| Availability | Max Downtime/Month |
|-------------|-------------------|
| 99% | ~7.2 hours |
| 99.9% | ~43 minutes |
| 99.99% | ~4 minutes |
| 99.999% | ~26 seconds |

---

## ⚖️ Key Differences

| Feature | SLI | SLO | SLA |
|---------|-----|-----|-----|
| Type | Metric | Objective | Agreement |
| Focus | Measurement | Reliability Target | Customer Commitment |
| Used By | Engineers | Engineering/Product | Business/Customers |
| Legal Impact | No | No | Yes |

---

## 🏢 Common Real-World SLAs

| System Type | Typical SLA |
|-------------|-------------|
| Internal Apps | 99% |
| SaaS Platforms | 99.9% |
| Critical APIs | 99.95% |
| Banking Systems | 99.99%+ |

---

## 💡 Practical Example

API service running on AWS:

| Layer | Value |
|-------|-------|
| **SLI** | API request success rate |
| **SLO** | 99.95% successful requests over 30 days |
| **SLA** | 99.9% uptime guaranteed to customers |
