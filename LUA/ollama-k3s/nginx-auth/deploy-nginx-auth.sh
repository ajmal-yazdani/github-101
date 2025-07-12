#!/bin/bash
set -e

# Set correct kubeconfig at the start
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Deploying Nginx Auth in air-gapped K3s with Kubernetes Secrets"
echo "============================================================="

kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f -

echo "Creating API key secret..."
kubectl apply -f api-keys.yaml

if ! kubectl get secret -n nginx ollama-tls-cert-host &> /dev/null; then
  echo "Generating TLS certificate..."
  HOST=$(hostname -f)
  if [ -z "$HOST" ]; then HOST=$(hostname); fi
  mkdir -p ~/certs && cd ~/certs

  openssl genrsa -out tls.key 2048

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

  openssl req -new -key tls.key -out tls.csr -config openssl.cnf
  openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt     -extensions req_ext -extfile openssl.cnf

  kubectl create secret tls ollama-tls-cert-host --cert=tls.crt --key=tls.key -n nginx

  cd -
fi

kubectl apply -f nginx-auth-deployment.yaml
kubectl apply -f ollama-ingress-auth.yaml

kubectl rollout status deployment nginx-auth -n nginx

echo "Deployment complete!"
echo "You can now access the API using:"
echo "curl -H \"X-API-Key: 12345\" -k https://k3s-airgap/api/version"
