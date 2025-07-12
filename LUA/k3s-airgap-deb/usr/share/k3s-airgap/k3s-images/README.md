# K3s Airgap Images Download Instructions

## K3s Version
The current K3s version used in this package is: `v1.32.6+k3s1`

## Linux Instructions

To download the K3s airgap images on Linux:

```bash
# Create directory for K3s images (if not already present)
mkdir -p k3s-images
cd OAK3S/k3s-airgap-deb/usr/share/k3s-airgap/k3s-images/

# Download K3s airgap images
wget https://github.com/k3s-io/k3s/releases/download/v1.32.6%2Bk3s1/k3s-airgap-images-amd64.tar

# Verify the download
ls -la k3s-airgap-images-amd64.tar
```

Alternatively, you can use curl:

```bash
curl -Lo k3s-airgap-images-amd64.tar "https://github.com/k3s-io/k3s/releases/download/v1.32.6%2Bk3s1/k3s-airgap-images-amd64.tar"
```

## Windows Instructions

To download the K3s airgap images on Windows using PowerShell:

```powershell
# Create directory for K3s images (if not already present)
mkdir -Force k3s-images
cd k3s-images

# Download K3s airgap images
Invoke-WebRequest -Uri "https://github.com/k3s-io/k3s/releases/download/v1.32.6%2Bk3s1/k3s-airgap-images-amd64.tar" -OutFile "k3s-airgap-images-amd64.tar"

# Verify the download
Get-Item k3s-airgap-images-amd64.tar
```

Alternatively, you can use curl if available on your Windows system:

```powershell
curl.exe -Lo k3s-airgap-images-amd64.tar "https://github.com/k3s-io/k3s/releases/download/v1.32.6%2Bk3s1/k3s-airgap-images-amd64.tar"
```

## For Other Architectures

If you need images for a different architecture, replace `amd64` with your target architecture:

- For ARM64: `k3s-airgap-images-arm64.tar`
- For ARMv7: `k3s-airgap-images-arm.tar`

## Usage in Airgap Installation

These images need to be placed in the correct directory structure for the airgap installation. In a typical K3s airgap setup, the images tarball should be placed in:

```
/var/lib/rancher/k3s/agent/images/
```

For this packaging system, place the downloaded tarball in this directory before building the package.