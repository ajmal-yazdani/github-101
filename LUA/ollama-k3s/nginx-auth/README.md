# NGINX Auth Gateway for K3s Air-Gapped Environment

This package provides a custom OpenResty-based NGINX gateway with API Key authentication using Lua and Kubernetes Secrets. Designed for **air-gapped K3s clusters**, it proxies requests to Ollama and secures them via API keys.

---

## 📁 Project Structure

```
nginx-auth/
├── build-nginx-auth.sh         # Builds OpenResty image and saves tar
├── deploy-nginx-auth.sh        # Deploys to K3s, creates secrets, ingress
├── manage-api-key.sh           # Add/remove/list API keys in secret
├── Dockerfile                  # OpenResty + Lua + NGINX config
├── nginx.conf                  # Global NGINX config
├── default.conf                # Server block (API proxy with auth)
├── lua/
│   └── api-key-auth.lua        # Lua script for key validation
├── api-keys.yaml               # Initial Kubernetes Secret for keys
├── nginx-auth-deployment.yaml # Deployment + Service YAML
├── ollama-ingress-auth.yaml   # Ingress config
└── nginx-auth-offline.tar     # Prebuilt Docker image
```

---

## 🚀 Quick Start

### 1. Build Image (if not using provided tar)
```bash
chmod +x build-nginx-auth.sh
./build-nginx-auth.sh
```

### 2. Transfer image to air-gapped K3s node
```bash
scp nginx-auth-offline.tar user@k3s-node:/tmp/
```

### 3. Import image into K3s containerd
```bash
sudo k3s ctr images import nginx-auth-offline.tar
```

### 4. Deploy NGINX Auth Gateway
```bash
chmod +x deploy-nginx-auth.sh
./deploy-nginx-auth.sh
```

---

## 🔑 API Key Management

### List Keys
```bash
./manage-api-key.sh list
```

### Add Key
```bash
./manage-api-key.sh add "new-key-value"
```

### Remove Key
```bash
./manage-api-key.sh remove "existing-key-value"
```

> All keys are stored as Kubernetes secrets under namespace `nginx`.

---

## 🔍 Testing the Deployment

```bash
curl -H "X-API-Key: 12345" -k https://k3s-airgap/api/version
```

---

## ✅ Features

- 🔐 Secure API Key Auth via Lua
- 🔄 Dynamic Key Management (no rebuild)
- 🔒 TLS with Self-Signed Cert (or replace with valid cert)
- 🧩 Works in Air-Gapped K3s Environments
- ♻️ Uses Kubernetes Secrets for secure storage

---

## 🛡️ Notes

- The TLS cert is auto-generated if not present. Replace with your own in production.
- The `k3s-airgap` domain must resolve to your K3s node (use `/etc/hosts` if needed).
- API Keys are base64-encoded when stored in secrets.

