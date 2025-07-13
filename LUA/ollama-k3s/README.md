# Install Docker
```bash
sudo apt update
    sudo apt install apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io

sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker $USER
newgrp docker

```


# Deploying Ollama with Llama Model in Offline Mode on K3s Without a Registry

## Prerequisites

```bash
# Clean up existing Docker images (if needed)
sudo docker rmi -f $(sudo docker images -q)

# Verify no images remain
sudo docker images
```

## Step 1: Prepare Environment

Set up your environment with Docker installed.

## Step 2: Build and Save the Image

```bash
# Build the image
sudo docker build -t ollama-llama:offline .

sudo docker build -t ollama-llama:offline -f Dockerfile_ollama_llama . 

# Save the image to a tar file
sudo docker save ollama-llama:offline -o ollama-llama-offline.tar
```

## Step 3: Transfer the Tar File to K3s Node(s)

```bash
# Copy the tar file to your k3s node
scp ollama-llama-offline.tar user@k3s-node:/path/to/destination/
```

## Step 4: Import the Image into K3s

```bash
# On the k3s node, import the image
sudo k3s ctr images import ollama-llama-offline.tar
# Run with lower priority and more resources
sudo nice -n 19 k3s ctr --timeout 1h images import ollama-llama-offline.tar

# Verify the image was imported successfully
sudo k3s ctr images ls | grep ollama
```

## Step 5: Create the Kubernetes Manifest File

Create an `ollama-deployment.yaml` file with the appropriate configuration.

## Step 6: Deploy to the K3s Cluster

```bash
# Apply the manifest
kubectl apply -f ollama-deployment.yaml

# Check deployment status
kubectl get pods -l app=ollama
```

## Shell into the Pod
```bash
# Get an interactive shell in the pod
kubectl exec -it $(kubectl get pods -l app=ollama -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

# From inside the pod, check models
curl -s http://localhost:11434/api/tags

# To run a direct Ollama command (if ollama CLI is available in the container)
ollama list

# Exit the shell when done
exit
```

## Step 7: Verify the Deployment

```bash
# Port-forward to access Ollama API
kubectl port-forward svc/ollama 11434:11434
```

In another terminal, test the API:

```bash
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "llama3:latest",
  "prompt": "Hello, world!"
}'
```


## ollama base image preparation
```bash
cd home/vmadmin/OAK3S/ollama-k3s/
# Build the image
docker build -t ollama-base:offline .

# Save the image to a tar file (much smaller than before)
docker save ollama-base:offline -o ollama-base-offline.tar

# Import into K3s
sudo k3s ctr images import ollama-base-offline.tar
sudo nice -n 19 k3s ctr --timeout 1h images import ollama-base-offline.tar
# view the image
sudo k3s ctr images ls | grep ollama
```
## Prepare llam3 tar file
```bash
# Create the Container (if not already created)
sudo docker create --name temp-ollama ollama-llama:offline
# View contents of the model directory
sudo sudo docker export temp-ollama | tar -tvf - | grep "root/.ollama" | head -20
#Create a TAR File with All Model Files
# Create a directory to store the extracted files temporarily
mkdir -p ~/ollama-models-temp

# Copy model files from the container
sudo docker cp temp-ollama:/root/.ollama/. ~/ollama-models-temp/
sudo docker cp temp-ollama:/root/.ollama/. ~/OAK3S/ollama-k3s/ollama-models-temp/

# Create a compressed tar file of the models
cd ~/ollama-models-temp
sudo tar -czvf ~/ollama-models.tar.gz .

# Verify the tar file was created successfully
ls -lh ~/ollama-models.tar.gz

# Remove the temporary container when you're done
sudo docker rm temp-ollama

# Fix ownership of the resulting tar file
sudo chown vmadmin:vmadmin ~/ollama-models.tar.gz

# Delete ollama-models-temp folder
sudo rm -rf ~/ollama-models-temp
```

## Extract and Copy to HostPath
```bash
# Create the hostPath directory structure
sudo mkdir -p /opt/ollama
# Extract the tar file directly to the hostPath location
sudo tar -xzvf ~/ollama-models.tar.gz -C /opt/ollama
# Fix permissions
sudo chmod -R 755 /opt/ollama
sudo chmod 600 /opt/ollama/id_ed25519  # Keep private key secure

# check content
sudo ls -la /opt/ollama
sudo ls -la /opt/ollama/models/blobs/
# Check total size
sudo du -sh /opt/ollama
```

## Deploy the ollama POD
```bash

#Copy the K3s kubeconfig to your home directory (if not already done):
# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Copy and set permissions for the config file
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# Set KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config

# Apply the deployment
kubectl apply -f ollama-hostpath-deployment.yaml

# Check deployment status
kubectl get pods -l app=ollama
```

# Exposing Ollama in Air-Gapped K3s Environment via IP Address
## Step 1: Prepare NGINX Ingress Controller for Offline Installation
```bash
# Download the NGINX Ingress manifest
curl -o ingress-nginx.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.0/deploy/static/provider/cloud/deploy.yaml

# Download required container images
sudo docker pull registry.k8s.io/ingress-nginx/controller:v1.13.0
sudo docker pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b53cabe0

# Save images to tar files
docker save registry.k8s.io/ingress-nginx/controller:v1.13.0 -o ingress-controller.tar
docker save registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b53cabe0 -o webhook-certgen.tar

# Transfer these files to your air-gapped VM
# scp ingress-nginx.yaml ingress-controller.tar webhook-certgen.tar user@0.12.157.168:~/
```

## Import Commands for K3s
```bash
# Import both images
sudo k3s ctr images import ingress-controller.tar
# sudo k3s ctr images import webhook-certgen.tar

# Verify imports
sudo k3s ctr images ls | grep ingress-nginx

# Check controller version
sudo k3s ctr images ls | grep controller:v1.13.0

# Check webhook certgen version
sudo k3s ctr images ls | grep kube-webhook-certgen:v20231011-8b53cabe0
```
## Configure Ollama Ingress for HTTPS Access
```bash
# Create self-signed certificate for IP address
mkdir -p ~/certs && cd ~/certs
IP_ADDRESS="10.12.157.169"  # Replace with your actual IP

# Generate private key and certificate
openssl genrsa -out ollama-tls.key 2048
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
CN = ${IP_ADDRESS}

[req_ext]
subjectAltName = @alt_names

[alt_names]
IP.1 = ${IP_ADDRESS}
EOF

openssl req -new -key ollama-tls.key -out ollama-tls.csr -config openssl.cnf
openssl x509 -req -days 365 -in ollama-tls.csr -signkey ollama-tls.key -out ollama-tls.crt \
  -extensions req_ext -extfile openssl.cnf

# Create Kubernetes TLS secret
kubectl create secret tls ollama-tls-cert --cert=ollama-tls.crt --key=ollama-tls.key
```

## Install
```bash
kubectl apply -f nginx-configmap.yaml
kubectl apply -f nginx-ingress-clusterrole.yaml
kubectl apply -f nginx-ingress-rbac.yaml
kubectl apply -f nginx-ingress.yaml

kubectl apply -f ollama-ingress.yaml

# Verify everything is running
kubectl get pods,svc,configmaps -n nginx
# Check all resources in nginx namespace
kubectl get all -n nginx
# Check ingress controller logs again
kubectl logs -n nginx $(kubectl get pods -n nginx -l app=nginx-ingress -o jsonpath='{.items[0].metadata.name}')

# Check if the service endpoints are properly set
kubectl get endpoints -n nginx

kubectl apply -f nginx-ingress.yaml
kubectl apply -f nginx-configmap.yaml
kubectl apply -f ollama-ingress.yaml

# Restart the ingress controller to apply changes
kubectl rollout restart deployment nginx-ingress-controller -n nginx

# Check the logs for errors
kubectl logs -n nginx deployment/nginx-ingress-controller

curl -k https://10.12.157.168/api/version
curl -u api-key:assword -k https://10.12.157.168/api/version

curl -k -X POST https://10.12.157.168:/api/generate -d '{
  "model": "llama3",
  "prompt": "How are you",
  "stream": true
}'
```

# Auth
```bash
kubectl apply -f api-auth-service.yaml
kubectl rollout restart deployment -n nginx api-auth
kubectl rollout status deployment -n nginx api-auth
kubectl get pods -n nginx -l app=api-auth
kubectl logs -n nginx -l app=api-auth
curl -H "X-API-Key: 12345" -k https://10.12.157.169/api/version
curl -H "X-API-Key: 12345" -k https://k3s-airgap/api/version

# Create a secret with your API keys
kubectl create secret generic api-keys -n nginx from-literal=key1=12345
```

# host name
```bash
#!/bin/bash
# filepath: /home/vmadmin/OAK3S/ollama-k3s/setup-hostname-ssl.sh

set -e

echo "Setting up Ollama with hostname-based SSL certificates"
echo "======================================================"

# Get the hostname
HOST=$(hostname -f)
if [ -z "$HOST" ]; then
  echo "Error: Could not determine hostname. Using hostname command output instead."
  HOST=$(hostname)
fi

echo "Using hostname: $HOST"

# Create directory for certificates
mkdir -p ~/certs && cd ~/certs

echo "Generating SSL certificates for $HOST..."

# Generate private key
openssl genrsa -out ollama-tls.key 2048

# Create OpenSSL config file
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

# Generate CSR and self-signed certificate
openssl req -new -key ollama-tls.key -out ollama-tls.csr -config openssl.cnf
openssl x509 -req -days 365 -in ollama-tls.csr -signkey ollama-tls.key -out ollama-tls.crt \
  -extensions req_ext -extfile openssl.cnf

echo "Creating Kubernetes TLS secret..."
# Delete existing secret if it exists
kubectl delete secret ollama-tls-cert -n nginx --ignore-not-found

# Create new secret
kubectl create secret tls ollama-tls-cert --cert=ollama-tls.crt --key=ollama-tls.key -n nginx

# Update the ingress configuration
echo "Updating ingress configuration with hostname: $HOST"

cat > ~/OAK3S/ollama-k3s/ollama-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ollama-ingress
  namespace: nginx
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/auth-url: "http://api-auth.nginx.svc.cluster.local:8080/"
    nginx.ingress.kubernetes.io/auth-response-headers: "X-API-Key"
spec:
  tls:
  - hosts:
    - ${HOST}
    secretName: ollama-tls-cert
  rules:
  - host: ${HOST}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ollama
            port:
              number: 11434
EOF

# Apply the updated ingress configuration
kubectl apply -f ~/OAK3S/ollama-k3s/ollama-ingress.yaml

# Restart the ingress controller
kubectl rollout restart deployment nginx-ingress-controller -n nginx

echo "Waiting for ingress controller to restart..."
kubectl rollout status deployment nginx-ingress-controller -n nginx

echo "Setup complete!"
echo "You can now access Ollama using: curl -H \"X-API-Key: 12345\" -k https://${HOST}/api/version"
echo "To remove the need for -k flag, add the certificate to your trusted store."
#windows
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "`n10.12.157.169 k3s-airgap"
# linux
echo "10.12.157.169 k3s-airgap" | sudo tee -a /etc/hosts
```