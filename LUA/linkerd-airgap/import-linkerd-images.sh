#!/bin/bash
set -e

echo "Importing Linkerd core images..."
sudo k3s ctr images import linkerd-images.tar

echo "Importing Linkerd Viz images..."
sudo k3s ctr images import linkerd-viz-images.tar

echo "All Linkerd images have been imported into K3s containerd."