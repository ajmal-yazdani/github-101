#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Helper functions
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${1}"
}

error() {
    log "${RED}ERROR: ${1}${NC}"
    exit 1
}

# Display uninstall header
log "\nUninstalling Nginx Auth and cleaning up resources"
log "============================================================="

# Set kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Remove Kubernetes resources
log "${YELLOW}Removing Kubernetes resources...${NC}"

# Remove ingress
log "Removing ingress..."
kubectl delete -f ollama-ingress-auth.yaml --ignore-not-found=true || true

# Remove deployments
log "Removing deployments..."
kubectl delete -f nginx-auth-deployment.yaml --ignore-not-found=true || true
kubectl delete -f ollama-hostpath-deployment.yaml --ignore-not-found=true || true

# Remove secrets
log "Removing secrets..."
kubectl delete secret -n nginx ollama-tls-cert-host --ignore-not-found=true || true
kubectl delete secret -n nginx api-keys --ignore-not-found=true || true

# Remove namespace (this will remove all resources in the namespace)
log "Removing nginx namespace..."
kubectl delete namespace nginx --ignore-not-found=true || true

# Remove container images
log "${YELLOW}Removing container images from k3s...${NC}"
k3s ctr images rm $(k3s ctr images list | grep 'nginx-auth' | awk '{print $1}') 2>/dev/null || true
k3s ctr images rm $(k3s ctr images list | grep 'ollama' | awk '{print $1}') 2>/dev/null || true

# Remove Ollama models and data
log "${YELLOW}Removing Ollama models and data...${NC}"
if [ -d "/opt/ollama" ]; then
    log "Removing /opt/ollama directory..."
    sudo rm -rf /opt/ollama
fi

# Remove local files
# log "${YELLOW}Removing local files...${NC}"
# rm -f nginx-auth-offline.tar ollama-base-offline.tar 2>/dev/null || true
# rm -f ollama-models.tar.gz 2>/dev/null || true

# Remove temporary files
log "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf /tmp/k3s-* 2>/dev/null || true

# Final cleanup verification
log "${YELLOW}Verifying cleanup...${NC}"
kubectl get all -n nginx --ignore-not-found=true
if [ -d "/opt/ollama" ]; then
    log "${RED}WARNING: /opt/ollama directory still exists${NC}"
fi

# Display completion message
log "${GREEN}✅ Uninstallation complete!${NC}"
log "${YELLOW}Note: To completely remove K3s, you can run:${NC}"
log "    /usr/local/bin/k3s-uninstall.sh"