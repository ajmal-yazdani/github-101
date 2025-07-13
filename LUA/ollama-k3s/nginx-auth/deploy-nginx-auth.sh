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

# Display deployment header
log "\nDeploying Nginx Auth in air-gapped K3s with Kubernetes Secrets"
log "============================================================="

# Get hostname
HOST=$(hostname -f)
if [ -z "$HOST" ]; then 
    HOST=$(hostname)
    log "${YELLOW}WARNING: Could not get FQDN, using short hostname: ${HOST}${NC}"
fi

# Set kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Create namespace
log "${YELLOW}Creating nginx namespace...${NC}"
kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f -

# Setup TLS certificate
log "${YELLOW}Setting up TLS certificate...${NC}"
if ! kubectl get secret -n nginx ollama-tls-cert-host &> /dev/null; then
    CERT_DIR=$(mktemp -d)
    cd "${CERT_DIR}"

    openssl genrsa -out tls.key 2048 || error "Failed to generate private key"

    cat > openssl.cnf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = US
ST = State
L = City
O = Organization
OU = OrganizationalUnit
CN = ${HOST}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HOST}
EOF

    openssl req -new -key tls.key -out tls.csr -config openssl.cnf || error "Failed to generate CSR"
    openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt \
        -extensions req_ext -extfile openssl.cnf || error "Failed to generate certificate"

    kubectl create secret tls ollama-tls-cert-host --cert=tls.crt --key=tls.key -n nginx || \
        error "Failed to create TLS secret"
    
    cd - > /dev/null
    rm -rf "${CERT_DIR}"
fi

# Create API key secret
log "${YELLOW}Creating API key secret...${NC}"
kubectl apply -f api-keys.yaml || error "Failed to apply API keys"

# Extract and setup Ollama models
log "${YELLOW}Setting up Ollama models...${NC}"
sudo mkdir -p /opt/ollama || error "Failed to create /opt/ollama directory"

# Change from ~/ollama-models.tar.gz to ./ollama-models.tar.gz
sudo tar -xzvf ./ollama-models.tar.gz -C /opt/ollama || error "Failed to extract ollama-models.tar.gz"
sudo chmod -R 755 /opt/ollama
sudo chmod 600 /opt/ollama/id_ed25519

# Verify Ollama installation
log "${YELLOW}Verifying Ollama installation:${NC}"
sudo ls -la /opt/ollama
sudo ls -la /opt/ollama/models/blobs/
sudo du -sh /opt/ollama

# Import container images
log "${YELLOW}Importing container images...${NC}"
MAX_ATTEMPTS=3

for TARFILE in ollama-base-offline.tar nginx-auth-offline.tar; do
    if [ ! -f "$TARFILE" ]; then
        error "Required tarfile not found: $TARFILE"
    fi
    
    for ((ATTEMPT=1; ATTEMPT<=MAX_ATTEMPTS; ATTEMPT++)); do
        log "Importing $TARFILE (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
        if sudo nice -n 19 k3s ctr --timeout 1h images import "$TARFILE" &>/dev/null; then
            log "${GREEN}Successfully imported $TARFILE${NC}"
            break
        fi
        
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            error "Failed to import $TARFILE after $MAX_ATTEMPTS attempts"
        fi
        log "${YELLOW}Retrying in 5 seconds...${NC}"
        sleep 5
    done
done

# Apply Kubernetes manifests
log "${YELLOW}Applying Kubernetes manifests...${NC}"
kubectl apply -f ollama-hostpath-deployment.yaml || error "Failed to apply ollama deployment"
kubectl apply -f nginx-auth-deployment.yaml || error "Failed to apply nginx-auth deployment"
kubectl apply -f ollama-ingress-auth.yaml || error "Failed to apply ingress"

# Wait for deployment
log "${YELLOW}Waiting for nginx-auth deployment to be ready...${NC}"
kubectl rollout status deployment nginx-auth -n nginx || error "nginx-auth deployment failed"

# Display success message
log "${GREEN}✅ Deployment complete!${NC}"
log "${YELLOW}You can now access the API using:${NC}"
log "curl -H \"X-API-Key: 12345\" -k https://${HOST}/api/version"