#!/bin/bash
set -e

echo "✔ K3s binary is already placed at /usr/local/bin/k3s"

# Ensure the binary is executable
chmod +x /usr/local/bin/k3s

# Load airgap images
if [ -f /var/lib/k3s/images/k3s-airgap-images-amd64.tar ]; then
    echo "📦 Loading airgap images into containerd..."
    /usr/local/bin/k3s ctr images import /var/lib/k3s/images/k3s-airgap-images-amd64.tar
fi

# Start and enable the k3s service
echo "🚀 Enabling and starting K3s systemd service..."
systemctl daemon-reexec
systemctl enable k3s
systemctl restart k3s

echo "✅ K3s air-gapped installation completed."
