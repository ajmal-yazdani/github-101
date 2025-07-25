#!/bin/bash
# Air-gapped K3s installation script with EventRateLimit and etcd snapshot configuration

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting air-gapped K3s installation...${NC}"

# Copy k3s binary from local package
echo -e "${YELLOW}Copying k3s binary to /usr/local/bin...${NC}"
if [ -f ./bin/k3s ]; then
    sudo cp ./bin/k3s /usr/local/bin/k3s
    sudo chmod +x /usr/local/bin/k3s
    echo -e "${GREEN}k3s binary installed at /usr/local/bin/k3s${NC}"
else
    echo -e "${RED}ERROR: ./bin/k3s not found!${NC}"
    exit 1
fi

if [ ! -x /usr/local/bin/k3s ]; then
    echo -e "${RED}K3s binary not found at /usr/local/bin/k3s. Please copy it there and make it executable.${NC}"
    exit 1
fi

# Create required directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
sudo mkdir -p /etc/rancher/k3s
sudo mkdir -p /opt/k3s-data/{server/{db/etcd,tls,manifests,conf},snapshots}
sudo chown -R root:root /opt/k3s-data
sudo chmod 700 /opt/k3s-data/server/db/etcd
sudo chmod 700 /opt/k3s-data/server/tls
sudo chmod 700 /opt/k3s-data/snapshots

# Write EventRateLimit config
echo -e "${YELLOW}Writing EventRateLimit configuration...${NC}"
sudo tee /opt/k3s-data/server/conf/event-rate-limit.yaml > /dev/null << EOF
apiVersion: eventratelimit.admission.k8s.io/v1alpha1
kind: Configuration
limits:
- type: Server
  qps: 2000
  burst: 4000
  cacheSize: 20000
- type: Namespace
  qps: 300
  burst: 600
  cacheSize: 3000
EOF

# Write AdmissionConfiguration file
echo -e "${YELLOW}Writing AdmissionConfiguration file...${NC}"
sudo tee /opt/k3s-data/server/conf/admission-control.yaml > /dev/null << EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: EventRateLimit
  path: /opt/k3s-data/server/conf/event-rate-limit.yaml
EOF

# Secure configs
sudo chmod 600 /opt/k3s-data/server/conf/*.yaml
sudo chown root:root /opt/k3s-data/server/conf/*.yaml

# Write K3s config
echo -e "${YELLOW}Writing K3s config file...${NC}"
sudo tee /etc/rancher/k3s/config.yaml > /dev/null << EOF
data-dir: /opt/k3s-data
write-kubeconfig-mode: "644"
disable:
  - traefik
cluster-init: true
etcd-snapshot: true
etcd-snapshot-schedule-cron: "0 */3 * * *"
etcd-snapshot-retention: 5
etcd-snapshot-dir: "/opt/k3s-data/snapshots"
kube-apiserver-arg:
  - "enable-admission-plugins=NodeRestriction,EventRateLimit"
  - "admission-control-config-file=/opt/k3s-data/server/conf/admission-control.yaml"
EOF

# Create kubectl symlink
echo -e "${YELLOW}Creating kubectl symlink...${NC}"
if [ ! -f /usr/local/bin/kubectl ]; then
    sudo ln -s /usr/local/bin/k3s /usr/local/bin/kubectl
    echo -e "${GREEN}kubectl symlink created at /usr/local/bin/kubectl${NC}"
fi

# Setup systemd service
echo -e "${YELLOW}Installing K3s systemd service...${NC}"
sudo tee /etc/systemd/system/k3s.service > /dev/null << EOF
[Unit]
Description=Lightweight Kubernetes
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
ExecStart=/usr/local/bin/k3s server --config /etc/rancher/k3s/config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start K3s
echo -e "${YELLOW}Starting K3s...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable k3s
sudo systemctl start k3s

# Wait for containerd to be ready
echo -e "${YELLOW}Waiting for K3s containerd socket to be ready...${NC}"
timeout=60
elapsed=0
while [ ! -S /run/k3s/containerd/containerd.sock ]; do
  sleep 1
  elapsed=$((elapsed + 1))
  if [ $elapsed -ge $timeout ]; then
    echo -e "${RED}Timeout waiting for containerd.sock!${NC}"
    exit 1
  fi
done

# Import container images
echo -e "${YELLOW}Importing container images from ./k3s-images...${NC}"
if [ -d ./k3s-images ]; then
  for img in ./k3s-images/*.tar; do
    echo "Importing $img..."
    sudo /usr/local/bin/k3s ctr images import "$img"
  done
else
  echo -e "${RED}No ./k3s-images directory found. Skipping image import.${NC}"
fi

# Wait and verify
echo -e "${YELLOW}Waiting 60s for cluster to stabilize...${NC}"
sleep 60

echo -e "${YELLOW}Verifying cluster status...${NC}"
sudo systemctl status k3s --no-pager || true
sudo kubectl get nodes -o wide || true

# Logs
echo -e "${YELLOW}Recent errors (if any):${NC}"
sudo journalctl -u k3s --no-pager | grep -i error | tail -10 || true

echo -e "${GREEN}✅ Air-gapped K3s installation complete!${NC}"
