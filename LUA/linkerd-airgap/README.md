# Linkerd Setup for Air-Gapped K3s Environment

```bash
curl -sL https://run.linkerd.io/install | sh

export PATH=$PATH:$HOME/.linkerd2/bin

echo 'export PATH=$PATH:$HOME/.linkerd2/bin' >> ~/.zshrc
source ~/.zshrc


echo 'export PATH=$PATH:$HOME/.linkerd2/bin' >> ~/.bashrc
source ~/.bashrc

linkerd version

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

1. Generate CRDs for offline install:
linkerd install --crds --ignore-cluster | tee linkerd-crds.yaml
2. Generate Control Plane YAML without checking the cluster:
linkerd install --ignore-cluster | tee linkerd-control-plane.yaml
Optional: Viz Extension
linkerd install --crds --ignore-cluster | tee linkerd-crds.yaml
linkerd viz install --ignore-cluster | tee linkerd-viz.yaml
linkerd install --ignore-cluster | tee linkerd-control-plane.yaml
 linkerd viz install --ignore-cluster | tee linkerd-viz.yaml

 linkerd viz install --ignore-cluster | grep image: | awk '{print $2}' | sort -u >> linkerd-images.txt
sort -u linkerd-images.txt -o linkerd-images.txt

mkdir -p linkerd-images
while read img; do
  echo "Pulling $img..."
  docker pull "$img"
done < linkerd-images.txt

docker save $(cat linkerd-images.txt) -o linkerd-images.tar

```

This package enables mTLS, metrics, and observability using Linkerd in a K3s air-gapped environment.

## 🔧 Components Included
- Linkerd CRDs
- Linkerd Control Plane
- Linkerd Viz Extension (Dashboard)
- Ingress for Linkerd dashboard
- Shell scripts for importing images and deploying Linkerd


## 📦 Files
- `linkerd-crds.yaml`: Linkerd CRDs
- `linkerd-control-plane.yaml`: Linkerd control plane resources
- `linkerd-viz.yaml`: Linkerd Viz (dashboard) components
- `linkerd-dashboard-ingress.yaml`: Ingress definition for accessing the dashboard
- `import-linkerd-images.sh`: Script to import container images into K3s
- `install-linkerd.sh`: Script to deploy Linkerd CRDs, control plane, and Viz

## 🧪 Usage

### 1. Load Docker Images into K3s
```bash
chmod +x import-linkerd-images.sh
./import-linkerd-images.sh
```

### 2. Deploy Linkerd into K3s
```bash
chmod +x install-linkerd.sh
./install-linkerd.sh
```

### 3. Annotate Namespaces for mTLS
```bash
kubectl annotate ns nginx linkerd.io/inject=enabled
kubectl annotate ns ollama linkerd.io/inject=enabled
```

### 4. Apply Ingress for Dashboard
```bash
kubectl apply -f linkerd-dashboard-ingress.yaml
```

Then open in browser: `https://linkerd.k3s-airgap/`

Ensure you add this to `/etc/hosts` if needed.

## 🧰 Troubleshooting
- `linkerd check`
- `linkerd viz stat deploy -n nginx`
- `linkerd viz tap deploy/nginx-auth -n nginx`