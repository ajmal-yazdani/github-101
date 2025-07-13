#!/bin/bash
set -e

echo "Applying Linkerd CRDs..."
kubectl apply -f linkerd-crds.yaml

echo "Deploying Linkerd control plane..."
kubectl apply -f linkerd-control-plane.yaml

echo "Deploying Linkerd Viz extension..."
kubectl apply -f linkerd-viz.yaml

echo "Waiting for all deployments to be ready..."
kubectl rollout status deploy/linkerd-controller -n linkerd
kubectl rollout status deploy/linkerd-proxy-injector -n linkerd
kubectl rollout status deploy/prometheus -n linkerd-viz
kubectl rollout status deploy/web -n linkerd-viz

echo "Linkerd installation complete."