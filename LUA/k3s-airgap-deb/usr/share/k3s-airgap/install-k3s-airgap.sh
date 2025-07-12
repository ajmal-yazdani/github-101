#!/bin/bash

# Define colors for console output
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration paths
CONFIG_DIR="/etc/rancher/k3s"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
K3S_DATA_DIR="/opt/k3s-data"
AIRGAP_TARBALL="./k3s-images/k3s-airgap-images-amd64.tar"
K3S_BINARY="/usr/local/bin/k3s"
K3S_INSTALL_DIR="/usr/local/bin"
ADMISSION_CONTROL_DIR="${K3S_DATA_DIR}/server/conf"
ADMISSION_CONTROL_FILE="${ADMISSION_CONTROL_DIR}/admission-control.yaml"
K3S_SERVICE_FILE="/etc/systemd/system/k3s.service"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p ${CONFIG_DIR}
mkdir -p ${K3S_DATA_DIR}
mkdir -p ${K3S_DATA_DIR}/snapshots
mkdir -p ${ADMISSION_CONTROL_DIR}

# Copy configuration file from the package
echo -e "${YELLOW}Setting up K3s configuration...${NC}"
if [ -f "./etc/rancher/k3s/config.yaml" ]; then
  cp ./etc/rancher/k3s/config.yaml ${CONFIG_FILE}
  echo -e "${GREEN}Configuration file copied to ${CONFIG_FILE}${NC}"
else
  echo -e "${RED}Configuration file not found in package!${NC}"
  exit 1
fi

# Copy admission control configs from package
echo -e "${YELLOW}Setting up admission control configuration...${NC}"
if [ -f "./opt/k3s-data/server/conf/admission-control.yaml" ] && [ -f "./opt/k3s-data/server/conf/event-rate-limit.yaml" ]; then
  # Copy both configuration files
  cp ./opt/k3s-data/server/conf/admission-control.yaml ${ADMISSION_CONTROL_FILE}
  cp ./opt/k3s-data/server/conf/event-rate-limit.yaml ${ADMISSION_CONTROL_DIR}/
  echo -e "${GREEN}Admission control configuration set up${NC}"
else
  echo -e "${RED}Admission control configuration files not found in package!${NC}"
  exit 1
fi

# Install K3s binary if not present at destination
echo -e "${YELLOW}Checking K3s binary...${NC}"
if [ ! -f "${K3S_BINARY}" ]; then
  echo -e "${YELLOW}K3s binary not found at ${K3S_BINARY}, installing...${NC}"
  if [ -f "./k3s" ]; then
    cp ./k3s ${K3S_INSTALL_DIR}/
    chmod +x ${K3S_INSTALL_DIR}/k3s
    echo -e "${GREEN}K3s binary installed to ${K3S_BINARY}${NC}"
  elif [ -f "./bin/k3s" ]; then
    cp ./bin/k3s ${K3S_INSTALL_DIR}/
    chmod +x ${K3S_INSTALL_DIR}/k3s
    echo -e "${GREEN}K3s binary installed from ./bin/k3s to ${K3S_BINARY}${NC}"
  else
    echo -e "${RED}K3s binary not found in package!${NC}"
    echo -e "${RED}Please ensure k3s binary is available at ./k3s or ./bin/k3s${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}K3s binary already exists at ${K3S_BINARY}${NC}"
fi

# Create kubectl symlink
echo -e "${YELLOW}Creating kubectl symlink...${NC}"
if [ ! -f /usr/local/bin/kubectl ]; then
    ln -s ${K3S_BINARY} /usr/local/bin/kubectl
    echo -e "${GREEN}kubectl symlink created at /usr/local/bin/kubectl${NC}"
else
    echo -e "${GREEN}kubectl already exists at /usr/local/bin/kubectl${NC}"
fi

# Copy K3s systemd service file
echo -e "${YELLOW}Setting up K3s systemd service...${NC}"
if [ -f "./etc/systemd/system/k3s.service" ]; then
  cp ./etc/systemd/system/k3s.service ${K3S_SERVICE_FILE}
  echo -e "${GREEN}K3s service file copied to ${K3S_SERVICE_FILE}${NC}"
else
  echo -e "${RED}K3s service file not found!${NC}"
  echo -e "${RED}Please ensure the service file is available at ./etc/systemd/system/k3s.service${NC}"
  exit 1
fi

# Reload systemd to recognize the new service
echo -e "${YELLOW}Reloading systemd daemon...${NC}"
systemctl daemon-reload

# Start K3s service
echo -e "${YELLOW}Starting K3s service...${NC}"
systemctl enable k3s
systemctl start k3s || {
  echo -e "${RED}Failed to start K3s service!${NC}"
  echo -e "${YELLOW}Checking service status...${NC}"
  systemctl status k3s
  exit 1
}

# Wait for containerd to be fully ready
echo -e "${YELLOW}Waiting for K3s containerd socket to be ready...${NC}"
timeout=120  # Increased timeout
elapsed=0
while true; do
  # First check if the socket file exists
  if [ -S /run/k3s/containerd/containerd.sock ]; then
    echo -e "${YELLOW}Socket file exists, checking if containerd is responding...${NC}"
    # Try a simple ctr command to test the connection
    if ${K3S_BINARY} ctr version &>/dev/null; then
      echo -e "${GREEN}Containerd is responding correctly${NC}"
      break
    else
      echo -e "${YELLOW}Socket file exists but containerd is not responding yet...${NC}"
    fi
  fi
  
  sleep 5
  elapsed=$((elapsed + 5))
  echo -e "${YELLOW}Waited ${elapsed}/${timeout} seconds for containerd...${NC}"
  
  if [ $elapsed -ge $timeout ]; then
    echo -e "${RED}Timeout waiting for containerd to be fully ready!${NC}"
    echo -e "${YELLOW}Checking K3s service status:${NC}"
    systemctl status k3s
    echo -e "${YELLOW}Checking for socket file:${NC}"
    ls -la /run/k3s/containerd/
    exit 1
  fi
done
echo -e "${GREEN}Containerd is fully ready.${NC}"

# Import the airgap images tarball
echo -e "${YELLOW}Importing K3s airgap images...${NC}"
if [ -f "$AIRGAP_TARBALL" ]; then
  echo -e "Importing images from $AIRGAP_TARBALL..."
  
  # Add retry logic for image import
  max_attempts=3
  attempt=1
  import_success=false
  
  while [ $attempt -le $max_attempts ] && [ "$import_success" = false ]; do
    echo -e "${YELLOW}Import attempt $attempt of $max_attempts${NC}"
    if ${K3S_BINARY} ctr images import "$AIRGAP_TARBALL"; then
      echo -e "${GREEN}Successfully imported airgap images.${NC}"
      import_success=true
    else
      echo -e "${YELLOW}Attempt $attempt failed. Waiting before retry...${NC}"
      sleep 10
      attempt=$((attempt + 1))
    fi
  done
  
  if [ "$import_success" = false ]; then
    echo -e "${RED}Failed to import airgap images after $max_attempts attempts!${NC}"
    exit 1
  fi
else
  echo -e "${RED}Airgap images file not found at $AIRGAP_TARBALL${NC}"
  echo -e "${YELLOW}Please ensure the K3s airgap images tarball exists at this location${NC}"
  exit 1
fi

# Set KUBECONFIG environment variable
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo -e "${YELLOW}Setting KUBECONFIG environment variable${NC}"

# Wait for K3s to be ready
echo -e "${YELLOW}Waiting for K3s to be ready...${NC}"
timeout=120
elapsed=0
while ! kubectl get nodes &>/dev/null; do
  sleep 2
  elapsed=$((elapsed + 2))
  if [ $elapsed -ge $timeout ]; then
    echo -e "${RED}Timeout waiting for K3s to be ready!${NC}"
    exit 1
  fi
done

# Display cluster info
echo -e "${GREEN}K3s cluster is ready!${NC}"
kubectl get nodes -o wide
echo -e "${GREEN}K3s air-gapped installation completed successfully!${NC}"