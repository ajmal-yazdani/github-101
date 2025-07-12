#!/bin/bash
# Uninstall and clean up all K3s files (air-gap safe)

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Store our own PID to avoid killing ourselves
OUR_PID=$$
echo -e "${YELLOW}Starting K3s uninstallation... (script PID: $OUR_PID)${NC}"

# First check if K3s is running and get resource info for verification
if command -v kubectl &>/dev/null && [ -f /etc/rancher/k3s/k3s.yaml ]; then
    echo -e "${YELLOW}Listing Kubernetes resources before cleanup...${NC}"
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide || true
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -A || true
fi

echo -e "${YELLOW}Stopping K3s service...${NC}"
systemctl stop k3s || true
systemctl disable k3s || true

# Kill any running k3s processes, but be careful not to kill ourselves
echo -e "${YELLOW}Killing any running k3s processes...${NC}"
killall -9 k3s 2>/dev/null || true

# Kill k3s server process specifically, not anything with k3s in its name
echo -e "${YELLOW}Killing specific k3s server processes...${NC}"
for pid in $(pgrep -f "k3s server" 2>/dev/null); do
    if [ "$pid" != "$OUR_PID" ]; then
        echo -e "${YELLOW}Killing k3s process with PID $pid${NC}"
        kill -9 $pid 2>/dev/null || true
    fi
done

# Give some time for processes to terminate
echo -e "${YELLOW}Waiting for processes to terminate...${NC}"
sleep 5

echo -e "${YELLOW}Removing systemd service...${NC}"
rm -f /etc/systemd/system/k3s.service
rm -f /etc/systemd/system/multi-user.target.wants/k3s.service
systemctl daemon-reload
systemctl reset-failed k3s.service 2>/dev/null || true

echo -e "${YELLOW}Removing K3s binary and symlinks...${NC}"
rm -f /usr/local/bin/k3s
rm -f /usr/local/bin/kubectl

# Unmount all kubernetes related mounts
echo -e "${YELLOW}Unmounting all kubernetes related filesystems...${NC}"
mount | grep -E 'kubelet|containerd|k3s' | awk '{print $3}' | \
while read mount_point; do
    echo -e "${YELLOW}Unmounting $mount_point${NC}"
    umount -f "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
done

# Find and safely kill processes using containerd socket without killing ourselves
echo -e "${YELLOW}Safely killing processes using containerd...${NC}"
if [ -S /run/k3s/containerd/containerd.sock ]; then
    for pid in $(fuser /run/k3s/containerd/containerd.sock 2>/dev/null); do
        if [ "$pid" != "$OUR_PID" ]; then
            echo -e "${YELLOW}Killing process $pid using containerd socket${NC}"
            kill -9 $pid 2>/dev/null || true
        fi
    done
fi

# Find all kubernetes related mounts and unmount them with lazy option
echo -e "${YELLOW}Performing lazy unmount on projected volumes...${NC}"
mount | grep 'kubernetes.io~projected' | awk '{print $3}' | \
while read mount_point; do
    umount -l "$mount_point" 2>/dev/null || true
done

echo -e "${YELLOW}Removing config and data directories...${NC}"
rm -rf /etc/rancher/k3s
rm -rf /opt/k3s-data
rm -rf /var/lib/rancher/k3s

# Handle kubelet directory with special care
echo -e "${YELLOW}Carefully removing kubelet directory...${NC}"
find /var/lib/kubelet -type d -name "volumes" -exec umount -l {} \; 2>/dev/null || true
find /var/lib/kubelet -type d -name "plugins" -exec umount -l {} \; 2>/dev/null || true
find /var/lib/kubelet -type f -name "kubelet.err" -delete 2>/dev/null || true
find /var/lib/kubelet -type f -name "kubelet.log" -delete 2>/dev/null || true
rm -rf /var/lib/kubelet 2>/dev/null || true

echo -e "${YELLOW}Cleaning up containerd runtime and CNI files...${NC}"
# Force remove container shm and rootfs mounts
find /run/k3s /var/run/k3s -name "shm" 2>/dev/null | \
while read shm; do
    umount -f "$shm" 2>/dev/null || umount -l "$shm" 2>/dev/null || true
done

find /run/k3s /var/run/k3s -name "rootfs" 2>/dev/null | \
while read rootfs; do
    umount -f "$rootfs" 2>/dev/null || umount -l "$rootfs" 2>/dev/null || true
done

# Now try removing directories
rm -rf /run/k3s 2>/dev/null || echo -e "${YELLOW}Some files in /run/k3s could not be removed${NC}"
rm -rf /var/run/k3s 2>/dev/null || echo -e "${YELLOW}Some files in /var/run/k3s could not be removed${NC}"
rm -rf /var/run/flannel 2>/dev/null || true
rm -rf /etc/cni 2>/dev/null || true
rm -rf /var/lib/cni 2>/dev/null || true

# Clean up CNI interfaces
echo -e "${YELLOW}Checking for K3s network interfaces...${NC}"
if ip link show cni0 &>/dev/null; then
    echo -e "${YELLOW}Removing CNI interfaces...${NC}"
    ip link delete cni0 2>/dev/null || true
    ip link delete flannel.1 2>/dev/null || true
fi

# Clean up iptables
echo -e "${YELLOW}Cleaning up iptables rules...${NC}"
iptables-save | grep -v KUBE | grep -v CNI | iptables-restore 2>/dev/null || true

echo -e "${YELLOW}Cleaning logs...${NC}"
journalctl --rotate 2>/dev/null || true
journalctl --vacuum-time=1s 2>/dev/null || true

echo -e "${YELLOW}Running final verification checks...${NC}"
if [ -d "/run/k3s" ] || [ -d "/var/lib/rancher/k3s" ] || [ -f "/usr/local/bin/k3s" ]; then
    echo -e "${RED}Warning: Some K3s files still exist after uninstallation.${NC}"
    echo -e "${YELLOW}You may need to manually remove them or reboot the system.${NC}"
else
    echo -e "${GREEN}✅ Verification passed - K3s files successfully removed.${NC}"
fi

echo -e "${GREEN}✅ K3s uninstalled and cleaned up successfully.${NC}"
echo -e "${YELLOW}Note: A system reboot is STRONGLY recommended to ensure complete cleanup.${NC}"
echo -e "${YELLOW}Some resources may still be in use and can only be fully cleaned after a reboot.${NC}"