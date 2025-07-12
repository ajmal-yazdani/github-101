# K3s Binary Download Instructions

## K3s Version
The current K3s version used in this package is: `v1.32.6+k3s1`

## Linux Instructions

To download the K3s binary on Linux:

```bash
# Create directory for K3s binary
mkdir -p bin
cd /OAK3S/k3s-airgap-deb/usr/share/k3s-airgap/bin

# Download K3s binary
curl -Lo k3s "https://github.com/k3s-io/k3s/releases/download/v1.32.6%2Bk3s1/k3s"

# Make the binary executable
chmod +x k3s
```

## Windows Instructions

To download the K3s binary on Windows:

```powershell
# Create directory for K3s binary
mkdir -p bin
cd bin

# Download K3s binary
curl.exe -Lo k3s.exe "https://github.com/k3s-io/k3s/releases/download/v1.32.6%2Bk3s1/k3s.exe"
```

## Verification

After downloading, you can verify the binary by running:

```bash
# On Linux
./k3s --version

# On Windows
.\k3s.exe --version
```

## Additional Notes

- The K3s binary should be placed in the appropriate directory structure for the airgap installation package.
- Make sure the binary has appropriate execute permissions on Linux systems.
- For airgap installations, this binary needs to be downloaded before moving to an offline environment.