#!/bin/bash
# Uninstall and clean up all K3s files (air-gap safe)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping K3s service...${NC}"
sudo systemctl stop k3s || true
sudo systemctl disable k3s || true

echo -e "${YELLOW}Removing systemd service...${NC}"
sudo rm -f /etc/systemd/system/k3s.service
sudo systemctl daemon-reload

echo -e "${YELLOW}Removing K3s binary and symlinks...${NC}"
sudo rm -f /usr/local/bin/k3s
sudo rm -f /usr/local/bin/kubectl

echo -e "${YELLOW}Removing config and data directories...${NC}"
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /opt/k3s-data

echo -e "${YELLOW}Optional: Clearing logs...${NC}"
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s

echo -e "${GREEN}✅ K3s uninstalled and cleaned up successfully.${NC}"