# GCP IAM Role Binding

## 📖 Overview
Role Binding = **Assigning a Role to a Principal on a Resource**

It answers: **WHO** can do **WHAT** on **WHICH** resource

---

## 🧩 Components

| Component | Meaning | Example |
|-----------|---------|---------|
| Principal | Identity | user, service account |
| Role | Set of permissions | `roles/compute.admin` |
| Resource | Where access applies | project, bucket |

---

## 🔗 IAM Policy Structure

```json
{
  "bindings": [
    {
      "role": "roles/storage.objectViewer",
      "members": [
        "user:dev@company.com"
      ]
    }
  ]
}
```

> **Key Insight:** Each binding = one role assignment to one or more members

---

## 📌 Key Concepts

### 1. Inheritance
```text
Org → Folder → Project → Resource
```
Access flows **downward** — a role granted at project level applies to all resources in it.

### 2. Least Privilege
- Always give minimum permissions
- Avoid `Owner` / `Editor` roles

### 3. Types of Roles

| Type | Description | Use |
|------|-------------|-----|
| Basic | `Owner`, `Editor`, `Viewer` | Avoid in production |
| Predefined | Granular, Google-managed | ✅ Recommended |
| Custom | User-defined | When predefined doesn't fit |

### 4. Multiple Bindings
- One user → multiple roles
- One role → multiple users

---

## ⚠️ Interview Points
- IAM is **policy-based**, not user-based
- Role binding happens via IAM policy
- Policies are **additive** (no deny by default)
- Fine-grained access = predefined/custom roles

## 💡 Example

Give read-only access to a bucket:

```bash
gcloud projects add-iam-policy-binding my-project \
  --member=user:dev@company.com \
  --role=roles/storage.objectViewer
```
