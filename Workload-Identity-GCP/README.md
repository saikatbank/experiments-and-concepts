# GCP Workload Identity

## 📖 Overview
Workload Identity is a **secure way for workloads (especially in GKE) to access GCP services WITHOUT service account keys**. It uses identity federation instead of static credentials.

## 🚨 Problem It Solves

**Old approach (BAD):**
- ❌ Download service account key (JSON)
- ❌ Store in pod / VM
- ❌ Risk: key leak = full access

**Workload Identity (GOOD):**
- ✅ No keys required
- ✅ Uses identity federation
- ✅ Short-lived tokens

---

## 🔄 How It Works

```text
Kubernetes Service Account (KSA)
        ↓ linked to
GCP Service Account (GSA)
        ↓
Pod uses KSA
        ↓
GCP trusts KSA → allows acting as GSA
```

### 🔗 Mapping Concept

| Kubernetes | GCP | Purpose |
|------------|-----|---------|
| KSA | Identity inside cluster | Pod-level identity |
| GSA | IAM identity | GCP resource access |
| Binding | KSA ↔ GSA mapping | Trust relationship |

---

## 🔐 IAM Binding (Critical Step)

```bash
gcloud iam service-accounts add-iam-policy-binding GSA_NAME \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/KSA_NAME]"
```

> **Key Insight:** This allows KSA to **impersonate** GSA

---

## ⚙️ Setup Steps (High-Level)

1. Enable Workload Identity on cluster
2. Create KSA
3. Create GSA
4. Bind KSA ↔ GSA
5. Annotate KSA with GSA email
6. Use pod with that KSA

---

## 📌 Key Concepts

### 1. Identity Federation
External identity (KSA) → GCP identity (GSA) — no credentials exchanged

### 2. No Static Credentials
No JSON keys. Uses **short-lived tokens** via OIDC token exchange.

### 3. Secure by Design
- Least privilege
- Scoped access per namespace/pod

---

## ⚠️ Interview Points
- Eliminates service account keys entirely
- Uses IAM role binding internally
- Based on **OIDC token exchange**
- Recommended approach for all GKE workloads

## 🔥 Common Mistakes
- ❌ Not adding `roles/iam.workloadIdentityUser` role
- ❌ Wrong namespace in binding member string
- ❌ Forgetting KSA annotation
- ❌ Using JSON keys instead of Workload Identity
