vmadmin@k3s-demo:~/OAK3S/ollama-k3s$ sudo nice -n 19 k3s ctr --timeout 1h images import ollama-llama-offline.tar
ERRO[0063] progress stream failed to recv                error="error reading from server: EOF"
ctr: rpc error: code = Unavailable desc = error reading from server: EOF
ERRO[0063] send stream ended without EOF                 error="error reading from server: EOF"
vmadmin@k3s-demo:~/OAK3S/ollama-k3s$ sudo nice -n 19 k3s ctr --timeout 1h images import ollama-llama-offline.tar
ERRO[0134] send stream ended without EOF                 error="error reading from server: EOF"
ERRO[0134] send failed                                   error=EOF
ERRO[0134] progress stream failed to recv                error="error reading from server: EOF"
ctr: rpc error: code = Unavailable desc = error reading from server: EOF
vmadmin@k3s-demo:~/OAK3S/ollama-k3s$ sudo nice -n 19 k3s ctr --timeout 1h images import ollama-llama-offline.tar
ERRO[0049] progress stream failed to recv                error="error reading from server: EOF"
ERRO[0049] send stream ended without EOF                 error="error reading from server: EOF"
ERRO[0049] send failed                                   error=EOF
ctr: rpc error: code = Unavailable desc = error reading from server: EOF
vmadmin@k3s-demo:~/OAK3S/ollama-k3s$ sudo nice -n 19 k3s ctr --timeout 1h images import ollama-llama-offline.tar
docker.io/library/ollama llama:offline          saved
application/vnd.oci.image.manifest.v1+json sha256:f000248e32620ee2b88a3fecf1dad30893cf563717dc28eb2f799c0af3e2b184
Importing       elapsed: 199.3s total:   0.0 B  (0.0 B/s)

Comprehensive K3s Configuration for Ollama Deployment
To optimize your K3s cluster for running Ollama with large language models, I'll create a comprehensive configuration across the service file, config.yaml, and installation script.

1. K3s Service File Modifications
Create or modify k3s.service:
```bash
[Unit]
Description=Lightweight Kubernetes (Optimized for Ollama LLM)
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/k3s
EnvironmentFile=-/etc/sysconfig/k3s
# Optimized resource flags for Ollama
ExecStart=/usr/local/bin/k3s server \
    --kubelet-arg="eviction-hard=memory.available<100Mi" \
    --kubelet-arg="eviction-soft=memory.available<300Mi" \
    --kubelet-arg="eviction-soft-grace-period=memory.available=90s" \
    --kubelet-arg="image-gc-high-threshold=90" \
    --kubelet-arg="image-gc-low-threshold=80" \
    --kubelet-arg="system-reserved=memory=1Gi,cpu=500m" \
    --kubelet-arg="kube-reserved=memory=500Mi,cpu=250m" \
    --kube-controller-manager-arg="node-monitor-grace-period=60s" \
    --kube-controller-manager-arg="node-monitor-period=5s" \
    --kube-apiserver-arg="max-requests-inflight=400" \
    --kube-apiserver-arg="max-mutating-requests-inflight=200" \
    --kube-scheduler-arg="percentageOfNodesToScore=30"
KillMode=process
Delegate=yes
# Restart with 5s delay on failures
Restart=always
RestartSec=5
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
```

2. K3s Config File Modifications
Create or modify config.yaml:

```bash
# K3s Configuration optimized for Ollama LLM workloads
# Disable components not needed for single-node use
disable:
  - traefik
  - servicelb
  - metrics-server

# Data directory
data-dir: /opt/k3s-data

# Tune container runtime settings
container-runtime-endpoint: unix:///run/k3s/containerd/containerd.sock
pause-image: rancher/pause:3.6

# Node labels
node-label:
  - "ollama-ready=true"
  - "node.kubernetes.io/instance-type=ollama-host"

# Resource reservations - ensures Ollama has enough resources
kubelet-arg:
  - "system-reserved=memory=1Gi,cpu=500m"
  - "kube-reserved=memory=500Mi,cpu=250m"
  - "eviction-hard=memory.available<100Mi,nodefs.available<5%"
  - "eviction-soft=memory.available<300Mi,nodefs.available<10%"
  - "eviction-soft-grace-period=memory.available=90s,nodefs.available=120s"
  - "image-gc-high-threshold=90"
  - "image-gc-low-threshold=80"
  - "fail-swap-on=false"  # Allow some swap usage for large models
  - "max-pods=110"  # Reasonable default

# Performance tuning for the API server
kube-apiserver-arg:
  - "max-requests-inflight=400"
  - "max-mutating-requests-inflight=200"

# Etcd tuning (if using embedded etcd)
etcd-expose-metrics: false
etcd-snapshot-schedule-cron: "0 */12 * * *"  # Every 12 hours
etcd-snapshot-retention: 5  # Keep 5 snapshots

# Logging configuration
log: /var/log/k3s.log
debug: false  # Set to true if troubleshooting

# Networking
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
cluster-dns: 10.43.0.10

# Containerd configuration
write-kubeconfig-mode: "0644"  # More permissive mode for easier access
```
3. Installation Script Enhancements
Add these optimizations to install-k3s-airgap.sh:

```bash
# Add these lines after the "Creating necessary directories" section

# Configure system for Ollama workloads
echo -e "${YELLOW}Optimizing system for Ollama workloads...${NC}"

# Configure swap (if needed)
if [ ! -f "/swapfile" ]; then
  echo -e "${YELLOW}Creating swap file for large model support...${NC}"
  fallocate -l 8G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
  echo -e "${GREEN}8GB swap file created and enabled${NC}"
fi

# Configure kernel parameters for container workloads
echo -e "${YELLOW}Configuring kernel parameters...${NC}"
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
vm.swappiness=10
vm.overcommit_memory=1
vm.overcommit_ratio=100
kernel.panic=10
kernel.panic_on_oops=1
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.conf.all.forwarding=1
EOF
sysctl --system

# Configure Transparent Huge Pages for ML workloads
echo -e "${YELLOW}Optimizing memory management for ML workloads...${NC}"
echo never > /sys/kernel/mm/transparent_hugepage/enabled || true
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local
chmod +x /etc/rc.local

# Create containerd config specifically for large images
echo -e "${YELLOW}Creating containerd configuration for large images...${NC}"
mkdir -p ${K3S_DATA_DIR}/agent/etc/containerd/
cat > ${K3S_DATA_DIR}/agent/etc/containerd/config.toml.tmpl <<EOF
[plugins.opt]
  path = "/opt/k3s-data/agent/containerd"

[plugins.cri]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"

[plugins.cri.containerd]
  snapshotter = "overlayfs"
  disable_snapshot_annotations = true

[plugins.cri.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.cri.containerd.runtimes.runc.options]
  SystemdCgroup = true

# Increase timeouts for large images
[plugins.cri.registry]
  config_path = "/etc/containerd/certs.d"
  
[plugins.cri.registry.mirrors."docker.io"]
  endpoint = ["https://registry-1.docker.io"]
  
[plugins.cri.registry.configs."registry-1.docker.io".tls]
  insecure_skip_verify = false

# Important settings for large images
[plugins.cri.registry.configs."registry-1.docker.io".auth]
  username = ""
  password = ""
  
# Increase timeouts for large image operations
[plugins.cri.containerd]
  snapshotter = "overlayfs"
  disable_snapshot_annotations = true
  disable_cgroup = false
  disable_apparmor = false
  restrict_oom_score_adj = true

# Ollama-specific optimizations
[plugins.cri.containerd.default_runtime]
  runtime_type = "io.containerd.runc.v2"

[plugins.cri.containerd.default_runtime.options]
  SystemdCgroup = true
  
# Set resource limits for containerd
[metrics]
  address = "127.0.0.1:1338"
  
[debug]
  level = "info"

[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5m"
  "io.containerd.timeout.shim.load" = "5m"
  "io.containerd.timeout.shim.shutdown" = "5m"
  "io.containerd.timeout.task.state" = "2m"
EOF
```

4. Post-Installation Script
Add this section at the end of your installation script to create a post-installation script for Ollama:

```bash
# Create a post-installation script for Ollama preparation
echo -e "${YELLOW}Creating Ollama preparation script...${NC}"
cat > /usr/local/bin/prepare-for-ollama.sh <<'EOF'
#!/bin/bash
# Prepare K3s for Ollama LLM workload

# Add node label if not already present
kubectl label node --all ollama-ready=true --overwrite

# Create namespace for Ollama
kubectl create namespace ollama 2>/dev/null || true

# Create a priorityclass for Ollama
cat <<EOC | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: ollama-priority
value: 1000000
globalDefault: false
description: "Priority class for Ollama LLM workloads"
EOC

# Create resource quota for the namespace
cat <<EOQ | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ollama-quota
  namespace: ollama
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "6"
    limits.memory: "12Gi"
EOQ

# Create a node affinity template
cat > /etc/rancher/k3s/node-affinity-template.yaml <<EOA
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: ollama-ready
          operator: In
          values:
          - "true"
EOA

echo "K3s is now prepared for Ollama deployment"
EOF

chmod +x /usr/local/bin/prepare-for-ollama.sh
echo -e "${GREEN}Created Ollama preparation script at /usr/local/bin/prepare-for-ollama.sh${NC}"
```
Key Features of This Configuration
Memory Management:

Reduced eviction thresholds (100Mi hard, 300Mi soft)
Added soft eviction grace periods
Configured system and Kubernetes resource reservations
Added swap support for large model operations
Performance Tuning:

Optimized image garbage collection thresholds
Tuned API server request handling
Optimized containerd for large image operations
Increased timeouts for large operations
Scheduler Optimizations:

Node labels for Ollama workloads
Modified scheduler settings for better pod placement
Priority class for Ollama workloads
Resource Controls:

Namespace quota for Ollama workloads
System-level optimizations (swappiness, etc.)
Container Runtime Optimizations:

Customized containerd configuration for large images
Extended timeouts for large operations
This comprehensive configuration should provide a stable and performant K3s environment specifically optimized for running Ollama LLM workloads.

Network Configuration Parameters
cluster-cidr: 10.42.0.0/16
Purpose: Defines the IP range used for pod networking within the cluster
Details: This is a Class A private network with 65,536 possible IP addresses
Impact for Ollama: Ensures sufficient IP addresses for all pods, including the Ollama deployment
Air-gapped relevance: In an air-gapped environment, having a non-conflicting internal network is crucial since you can't easily change it later
service-cidr: 10.43.0.0/16
Purpose: Defines the IP range used for Kubernetes service networking
Details: Separate from the pod CIDR to avoid conflicts
Impact for Ollama: Provides IPs for the Ollama service endpoint
Air-gapped relevance: Services will use these IPs for internal communication, ensuring they don't conflict with existing networks
cluster-dns: 10.43.0.10
Purpose: Specifies the IP address for the CoreDNS service
Details: This is the DNS server that pods will use for service discovery
Impact for Ollama: Allows Ollama to resolve other services by name
Air-gapped relevance: Critical for DNS resolution within the cluster since external DNS won't be available
Key K3s System Configuration
data-dir: /opt/k3s-data
Purpose: Specifies where K3s stores all its data
Details: Centralizes all K3s data in a single location
Impact for Ollama: Important for persistence of model data
Air-gapped consideration: This directory will need sufficient storage capacity for models (typically 5-10GB per model)
write-kubeconfig-mode: "644"
Purpose: Sets permissions for the kubeconfig file
Details: Makes the kubeconfig readable by users other than root
Impact: Allows non-root users to interact with the cluster
Air-gapped consideration: Simplifies cluster management in restrictive environments
disable: - traefik
Purpose: Disables the default ingress controller
Details: Removes an unnecessary component for simple Ollama deployments
Impact for Ollama: Reduces resource usage and potential conflicts
Air-gapped benefit: Fewer components that need updates/maintenance
Resource Management Parameters
--kubelet-arg="eviction-hard=memory.available<100Mi"
Purpose: Sets the threshold for when pods will be forcibly evicted
Details: Only evicts pods when available memory drops below 100Mi
Impact for Ollama: Prevents premature termination of Ollama during temporary memory spikes
Air-gapped consideration: Critical for stability since you can't easily pull images again
--kubelet-arg="system-reserved=memory=1Gi,cpu=500m"
Purpose: Reserves resources for system processes
Details: 1GB memory and 0.5 CPU cores won't be available to Kubernetes
Impact for Ollama: Ensures system stability even under Ollama's heavy load
Air-gapped consideration: Prevents system failures that would require outside assistance
--kubelet-arg="kube-reserved=memory=500Mi,cpu=250m"
Purpose: Reserves resources for Kubernetes components
Details: 500MB memory and 0.25 CPU cores for kube-system components
Impact for Ollama: Ensures Kubernetes control plane remains responsive
Air-gapped consideration: Prevents control plane failures that would be harder to troubleshoot
Etcd Configuration (Database)
etcd-snapshot: true
Purpose: Enables automatic etcd backups
Details: Creates periodic snapshots of the cluster state
Impact for Ollama: Provides recovery points if something breaks
Air-gapped consideration: Critical since you can't easily reinstall in air-gapped environments
etcd-snapshot-schedule-cron: "0 */3 * * *"
Purpose: Sets backup frequency
Details: Creates snapshots every 3 hours
Impact: Regular backups without excessive overhead
Air-gapped consideration: Balance between protection and resource usage
etcd-snapshot-retention: 5
Purpose: Number of snapshots to keep
Details: Stores 5 most recent snapshots
Impact: Provides multiple recovery points while managing disk usage
Air-gapped consideration: Prevents disk space issues while maintaining recovery options
Security Parameters
kube-apiserver-arg: - "enable-admission-plugins=NodeRestriction,EventRateLimit"
Purpose: Enables security plugins for the API server
Details:
NodeRestriction: Limits what nodes can modify
EventRateLimit: Prevents event flooding
Impact for Ollama: Adds security without affecting normal operation
Air-gapped consideration: Improves security posture in environments that can't easily receive security updates
admission-control-config-file=/opt/k3s-data/server/conf/admission-control.yaml
Purpose: Configures admission controllers
Details: Controls how API requests are validated and modified
Impact for Ollama: Ensures secure, consistent operation
Air-gapped consideration: Prevents misconfigurations that would be harder to fix
Ollama-Specific Optimizations
In your deployment file, the following settings are particularly important for Ollama in an air-gapped environment:

imagePullPolicy: IfNotPresent
Purpose: Prevents Kubernetes from trying to download images
Details: Uses locally available images without checking registries
Impact for Ollama: Essential for air-gapped operation
Air-gapped consideration: Prevents hanging/timeout during deployment
OLLAMA_NOPRUNE=true
Purpose: Prevents automatic removal of model files
Details: Ollama normally removes "unused" model files to save space
Impact: Ensures your pre-loaded models remain available
Air-gapped consideration: Critical since you can't re-download models
Resource Limits
Purpose: Defines resource allocation for Ollama
Details: Guarantees minimum resources and sets maximum usage
Impact: Ensures Ollama has enough resources for models while preventing it from consuming the entire system
Air-gapped consideration: Prevents system instability that would be harder to recover from
Best Practices for Air-Gapped Ollama Deployments
Pre-download all model files before going air-gapped
Use PVCs for model storage to prevent data loss during pod restarts
Implement node affinity to ensure Ollama pods run on nodes with sufficient resources
Use the init container pattern as shown in your deployment to copy models from the image to persistent storage
Enable the OLLAMA_NOPRUNE flag to prevent automatic removal of model files
These configurations create a robust, stable K3s environment optimized for running Ollama with large language models in an air-gapped setting, with proper networking isolation and resource management.

K3s Service File Contents Explained:
Key Sections Explained
[Unit] Section
Description: Brief description of the service
Documentation: Link to K3s documentation
Wants/After: Ensures networking is available before starting K3s
[Service] Section
Type=notify: Tells systemd that K3s will signal when it's started
EnvironmentFile: Optional files with environment variables
ExecStartPre: Loads required kernel modules
ExecStart: The actual command to start K3s
KillMode=process: Only kills the main process, not children
Restart=always: Always restarts if K3s stops
RestartSec=5: Waits 5 seconds before restarting
Limit settings*: Removes various system limits for K3s
[Install] Section
WantedBy=multi-user.target: Start K3s on system boot
Optimizations for Ollama
For running Ollama with large language models, these additional parameters would be beneficial in the ExecStart line:

These parameters:
ExecStart=/usr/local/bin/k3s server \
    --kubelet-arg="eviction-hard=memory.available<100Mi" \
    --kubelet-arg="eviction-soft=memory.available<300Mi" \
    --kubelet-arg="eviction-soft-grace-period=memory.available=90s" \
    --kubelet-arg="image-gc-high-threshold=90" \
    --kubelet-arg="image-gc-low-threshold=80" \
    --kubelet-arg="system-reserved=memory=1Gi,cpu=500m" \
    --kubelet-arg="kube-reserved=memory=500Mi,cpu=250m" \
    --kubelet-arg="fail-swap-on=false"

Prevent premature pod eviction when memory gets tight
Allow Ollama to use swap if needed
Reserve appropriate memory for system and Kubernetes components
Configure image garbage collection to be less aggressive
The service file works in conjunction with your Ollama deployment to ensure K3s provides a stable platform for running large language models in your air-gapped environment.



Changes to K3s Install Script for Ollama Optimization
Based on our earlier discussion, here are the key changes we should make to the K3s installation script for optimizing an air-gapped environment running Ollama with large language models:

1. System Configuration Changes
```bash
# Add to install-k3s-airgap.sh after creating directories

# Configure system for Ollama workloads
echo -e "${YELLOW}Optimizing system for Ollama workloads...${NC}"

# Configure swap for large model operations
if [ ! -f "/swapfile" ]; then
  echo -e "${YELLOW}Creating swap file for large model support...${NC}"
  fallocate -l 8G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
  echo -e "${GREEN}8GB swap file created and enabled${NC}"
fi

# Configure kernel parameters for container workloads
echo -e "${YELLOW}Configuring kernel parameters...${NC}"
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
vm.swappiness=10
vm.overcommit_memory=1
vm.overcommit_ratio=100
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.conf.all.forwarding=1
EOF
sysctl --system
```
2. K3s Service File Modifications
```bash
# Add to install-k3s-airgap.sh before installing K3s

# Create optimized k3s.service file
echo -e "${YELLOW}Creating optimized K3s service file...${NC}"
cat > ${K3S_SERVICE_FILE} <<EOF
[Unit]
Description=Lightweight Kubernetes (Optimized for Ollama LLM)
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/k3s
EnvironmentFile=-/etc/sysconfig/k3s
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s server \\
    --kubelet-arg="eviction-hard=memory.available<100Mi" \\
    --kubelet-arg="eviction-soft=memory.available<300Mi" \\
    --kubelet-arg="eviction-soft-grace-period=memory.available=90s" \\
    --kubelet-arg="image-gc-high-threshold=90" \\
    --kubelet-arg="image-gc-low-threshold=80" \\
    --kubelet-arg="system-reserved=memory=1Gi,cpu=500m" \\
    --kubelet-arg="kube-reserved=memory=500Mi,cpu=250m" \\
    --kubelet-arg="fail-swap-on=false" \\
    --config ${CONFIG_FILE}
KillMode=process
Delegate=yes
Restart=always
RestartSec=5
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}K3s service file created with Ollama optimizations${NC}"
```
3. Containerd Configuration
```bash
# Add to install-k3s-airgap.sh before starting K3s

# Create containerd config specifically for large images
echo -e "${YELLOW}Creating containerd configuration for large images...${NC}"
mkdir -p ${K3S_DATA_DIR}/agent/etc/containerd/
cat > ${K3S_DATA_DIR}/agent/etc/containerd/config.toml.tmpl <<EOF
[plugins.opt]
  path = "${K3S_DATA_DIR}/agent/containerd"

[plugins.cri]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"

[plugins.cri.containerd]
  snapshotter = "overlayfs"
  disable_snapshot_annotations = true

[plugins.cri.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.cri.containerd.runtimes.runc.options]
  SystemdCgroup = true

# Increase timeouts for large images
[plugins.cri.registry]
  config_path = "/etc/containerd/certs.d"
  
# Important settings for large images
[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5m"
  "io.containerd.timeout.shim.load" = "5m"
  "io.containerd.timeout.shim.shutdown" = "5m"
  "io.containerd.timeout.task.state" = "2m"
EOF
```
4. Post-Installation Helper Script

```bash
# Add to install-k3s-airgap.sh at the end

# Create a post-installation script for Ollama preparation
echo -e "${YELLOW}Creating Ollama preparation script...${NC}"
cat > /usr/local/bin/prepare-for-ollama.sh <<'EOF'
#!/bin/bash
# Prepare K3s for Ollama LLM workload

# Add node label for Ollama workloads
kubectl label node --all ollama-ready=true --overwrite

# Create namespace for Ollama
kubectl create namespace ollama 2>/dev/null || true

# Create a priorityclass for Ollama
cat <<EOC | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: ollama-priority
value: 1000000
globalDefault: false
description: "Priority class for Ollama LLM workloads"
EOC

# Create resource quota for the namespace
cat <<EOQ | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ollama-quota
  namespace: ollama
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "6"
    limits.memory: "12Gi"
EOQ

echo "K3s is now prepared for Ollama deployment"
EOF

chmod +x /usr/local/bin/prepare-for-ollama.sh
echo -e "${GREEN}Created Ollama preparation script at /usr/local/bin/prepare-for-ollama.sh${NC}"
```
5. Long Timeout for Air-Gapped Image Import
```bash
# Modify the image import section in install-k3s-airgap.sh

# Import airgap images with extended timeout
echo -e "${YELLOW}Importing airgap images with extended timeout...${NC}"
max_attempts=3
attempt=1
import_success=false

while [ $attempt -le $max_attempts ] && [ "$import_success" = false ]; do
  echo -e "${YELLOW}Attempt $attempt of $max_attempts to import airgap images...${NC}"
  if nice -n 19 ${K3S_BINARY} ctr --timeout 30m images import "${AIRGAP_TARBALL}" &>/dev/null; then
    echo -e "${GREEN}Successfully imported airgap images on attempt $attempt${NC}"
    import_success=true
  else
    echo -e "${RED}Failed to import airgap images (attempt $attempt)${NC}"
    attempt=$((attempt + 1))
    sleep 5
  fi
done
```
GitHub Copilot
Changes to K3s Install Script for Ollama Optimization
Based on our earlier discussion, here are the key changes we should make to the K3s installation script for optimizing an air-gapped environment running Ollama with large language models:

1. System Configuration Changes
2. K3s Service File Modifications
3. Containerd Configuration
4. Post-Installation Helper Script
5. Long Timeout for Air-Gapped Image Import
Benefits of These Changes
System-level optimizations: Swap, kernel parameters, and resource management configured for Ollama's needs

K3s service tuning: Modified eviction thresholds and memory management specifically for LLM workloads

Containerd configurations: Extended timeouts and optimized settings for handling large image files

Resource controls: Helper script to set up proper resource quotas and scheduling priorities

Import process improvements: Added resilience to the air-gapped image import process

These changes collectively address the key challenges of running Ollama in an air-gapped K3s environment, ensuring stability and preventing the system crashes you were experiencing when deploying large language models.

Post-Installation Script for Ollama in K3s
A comprehensive post-installation script for Ollama should handle system optimization, Kubernetes setup, and model verification. Here's what should be included:

```bash
#!/bin/bash
# Post-installation script for Ollama LLM on K3s
# Save as /usr/local/bin/setup-ollama.sh

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

echo -e "${YELLOW}===== Ollama on K3s Post-Installation Setup =====${NC}"

# 1. System optimizations
echo -e "${YELLOW}Applying system optimizations for LLM workloads...${NC}"

# Adjust memory management for ML workloads
echo -e "${YELLOW}Optimizing memory management...${NC}"
echo 1 > /proc/sys/vm/overcommit_memory
echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf

# Disable transparent hugepages (better for ML workloads)
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local
chmod +x /etc/rc.local

# 2. Kubernetes namespace and RBAC setup
echo -e "${YELLOW}Setting up Kubernetes resources for Ollama...${NC}"

# Create namespace
kubectl create namespace ollama 2>/dev/null || true
echo -e "${GREEN}Namespace 'ollama' created or already exists${NC}"

# Create priority class for Ollama
cat <<EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: ollama-priority
value: 1000000
globalDefault: false
description: "Priority class for Ollama LLM workloads"
EOF
echo -e "${GREEN}PriorityClass created for Ollama${NC}"

# Create resource quota
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ollama-quota
  namespace: ollama
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "6"
    limits.memory: "12Gi"
    pods: "5"
EOF
echo -e "${GREEN}Resource quota created for Ollama namespace${NC}"

# 3. Node labels and taints
echo -e "${YELLOW}Configuring node for Ollama workloads...${NC}"

# Label nodes
kubectl label nodes --all ollama-ready=true --overwrite
kubectl label nodes --all workload-type=ml --overwrite

# Optional: Add taint to dedicate nodes to Ollama
# Uncomment if you want to dedicate nodes only for Ollama
# kubectl taint nodes --all ollama=true:NoSchedule

# 4. Storage class verification
echo -e "${YELLOW}Verifying storage configuration...${NC}"
kubectl get sc
echo -e "${YELLOW}Ensure a storage class exists for Ollama's PVC${NC}"

# 5. Verify containerd settings
echo -e "${YELLOW}Checking containerd configuration...${NC}"
if grep -q "io.containerd.timeout.shim.cleanup.*5m" /var/lib/rancher/k3s/agent/etc/containerd/config.toml; then
  echo -e "${GREEN}Containerd timeouts are properly configured${NC}"
else
  echo -e "${YELLOW}Containerd may need timeout adjustments for large images${NC}"
  echo -e "${YELLOW}Consider adding longer timeouts to containerd config${NC}"
fi

# 6. Set up monitoring (optional)
echo -e "${YELLOW}Setting up basic Ollama monitoring...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ollama-prometheus-config
  namespace: ollama
data:
  prometheus.yml: |
    scrape_configs:
      - job_name: 'ollama'
        static_configs:
          - targets: ['ollama.ollama.svc.cluster.local:11434']
EOF
echo -e "${GREEN}Basic monitoring configuration created${NC}"

# 7. Create a helper script for model management
echo -e "${YELLOW}Creating Ollama model management script...${NC}"
cat > /usr/local/bin/ollama-models.sh <<'EOFM'
#!/bin/bash
# Helper script for managing Ollama models

POD=$(kubectl get pods -n ollama -l app=ollama -o jsonpath='{.items[0].metadata.name}')

case "$1" in
  list)
    kubectl exec -it -n ollama $POD -- ollama list
    ;;
  pull)
    if [ -z "$2" ]; then
      echo "Usage: $0 pull MODEL_NAME"
      exit 1
    fi
    kubectl exec -it -n ollama $POD -- ollama pull $2
    ;;
  info)
    if [ -z "$2" ]; then
      echo "Usage: $0 info MODEL_NAME"
      exit 1
    fi
    kubectl exec -it -n ollama $POD -- ollama show $2
    ;;
  *)
    echo "Usage: $0 {list|pull|info MODEL_NAME}"
    exit 1
    ;;
esac
EOFM
chmod +x /usr/local/bin/ollama-models.sh
echo -e "${GREEN}Created model management script at /usr/local/bin/ollama-models.sh${NC}"

# 8. Create deployment file if it doesn't exist
if [ ! -f "/home/$(logname)/ollama-deployment.yaml" ]; then
  echo -e "${YELLOW}Creating sample Ollama deployment file...${NC}"
  cat > "/home/$(logname)/ollama-deployment.yaml" <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-data
  namespace: ollama
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
      annotations:
        priorityClassName: "ollama-priority"
    spec:
      initContainers:
      - name: copy-models
        image: ollama-llama:offline
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "===== Starting init container ====="
            # Create target directory
            mkdir -p /mnt/ollama
            # Copy model files from image to PVC
            cp -rp /root/.ollama/* /mnt/ollama/
            # Create a flag file
            touch /mnt/ollama/models/.preloaded
        volumeMounts:
        - name: ollama-data
          mountPath: /mnt/ollama
        resources:
          limits:
            memory: "1Gi"
            cpu: "0.5"
      containers:
      - name: ollama
        image: ollama-llama:offline
        imagePullPolicy: IfNotPresent
        env:
        - name: OLLAMA_NOPRUNE
          value: "true"
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
        resources:
          limits:
            cpu: "4"
            memory: "8Gi"
          requests:
            cpu: "2"
            memory: "4Gi"
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-data
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: ollama
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
  type: ClusterIP
EOF
  echo -e "${GREEN}Created sample deployment at ~/ollama-deployment.yaml${NC}"
fi

# 9. Verification steps
echo -e "${YELLOW}Running verification checks...${NC}"
echo -e "${YELLOW}Checking node capacity...${NC}"
kubectl describe nodes | grep -A 5 "Capacity"
echo -e "${YELLOW}Checking storage classes...${NC}"
kubectl get sc
echo -e "${YELLOW}Checking available images...${NC}"
k3s ctr images ls | grep ollama

# 10. Final instructions
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Ollama post-installation setup complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo -e "${YELLOW}To deploy Ollama:${NC}"
echo -e "  kubectl apply -f ~/ollama-deployment.yaml"
echo -e "${YELLOW}To check status:${NC}"
echo -e "  kubectl get pods -n ollama"
echo -e "${YELLOW}To manage models:${NC}"
echo -e "  ollama-models.sh list"
echo -e "${YELLOW}To forward the API port:${NC}"
echo -e "  kubectl port-forward -n ollama svc/ollama 11434:11434"
echo -e "${GREEN}=====================================${NC}"
```

Key Components of this Script
System optimizations:

Memory management settings
Transparent hugepages configuration
Kubernetes resource setup:

Namespace creation
Priority class for Ollama workloads
Resource quotas to prevent overconsumption
Node configuration:

Labels for Ollama workloads
Optional taints for dedicated nodes
Containerd verification:

Checks for proper timeout settings
Basic monitoring setup:

Prometheus configuration
Helper scripts:

Model management utilities
Sample deployment template
Verification checks:

Node capacity
Storage classes
Available images
This post-installation script provides a comprehensive setup for running Ollama on K3s in an air-gapped environment, with proper resource management and monitoring.


Using hostPath Volumes for Ollama Model Storage
What are hostPath Volumes?
A hostPath volume mounts a file or directory from the host node's filesystem into your pod. This is different from a PersistentVolumeClaim (PVC) because:

The storage is tied directly to the node where the pod runs
Data persists even if the pod is deleted
It provides direct access to the host's filesystem
It can be pre-populated with files before the pod starts
For Ollama, using a hostPath volume for model storage means you can:

Pre-load large model files directly on the node
Avoid copying multi-gigabyte files during pod initialization
Share models between pod restarts without copying
Complete Ollama Deployment with hostPath
Here's a complete deployment YAML using the hostPath approach:

```bash
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-runtime-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      initContainers:
      - name: setup-models
        image: ollama-llama:offline
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "===== Starting setup container ====="
            
            # Create necessary directories in host path
            mkdir -p /host-models/blobs
            mkdir -p /host-models/manifests
            
            # Check if models already exist in host path
            if [ -f "/host-models/.initialized" ]; then
              echo "Host path already initialized with models"
            else
              echo "Initializing host path with models"
              
              # Copy model files from the image to the host path
              echo "Copying model blob files to host path..."
              cp -rp /root/.ollama/models/blobs/* /host-models/blobs/ || echo "No blob files found"
              
              # Copy model manifests
              echo "Copying model manifests to host path..."
              cp -rp /root/.ollama/models/manifests/* /host-models/manifests/ || echo "No manifests found"
              
              # Mark as initialized
              touch /host-models/.initialized
            fi
            
            # Create runtime structure in PVC
            mkdir -p /runtime-data/id
            
            # Copy SSH keys for Ollama API if they exist
            if [ -f "/root/.ollama/id_ed25519" ]; then
              cp /root/.ollama/id_ed25519* /runtime-data/id/ || true
            fi
            
            echo "Setup completed"
        volumeMounts:
        - name: ollama-model-data
          mountPath: /host-models
        - name: ollama-runtime-data
          mountPath: /runtime-data
      containers:
      - name: ollama
        image: ollama-llama:offline
        imagePullPolicy: IfNotPresent
        command: ["/bin/sh", "-c"]
        args:
          - |
            # Set environment variables
            export OLLAMA_NOPRUNE=true
            export OLLAMA_MODELS="/models"
            
            # Check models before starting server
            echo "Checking models before server start:"
            find /models -type f -size +100M -exec ls -lh {} \; || echo "No large model files found"
            find /models/manifests -type f -exec ls -lh {} \; || echo "No manifests found"
            
            # Copy runtime data
            if [ -d "/runtime-data/id" ]; then
              mkdir -p /root/.ollama
              cp -rp /runtime-data/id/* /root/.ollama/ || true
            fi
            
            # Start Ollama
            echo "Starting Ollama server..."
            exec /bin/ollama serve
        env:
        - name: OLLAMA_NOPRUNE
          value: "true"
        - name: GOMEMLIMIT
          value: "5Gi"
        - name: OLLAMA_MODELS
          value: "/models"
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: ollama-model-data
          mountPath: /models
          readOnly: true
        - name: ollama-runtime-data
          mountPath: /runtime-data
        resources:
          limits:
            cpu: "3"
            memory: "6Gi"
          requests:
            cpu: "2"
            memory: "4Gi"
      volumes:
      - name: ollama-model-data
        hostPath:
          path: /opt/ollama/models
          type: DirectoryOrCreate
      - name: ollama-runtime-data
        persistentVolumeClaim:
          claimName: ollama-runtime-data
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
  type: ClusterIP
```

Key Benefits of This Approach
Model persistence: Models are stored directly on the host node
Faster pod startup: No need to copy multi-gigabyte files during pod initialization
Reduced memory pressure: The copy operation that was causing OOM issues is eliminated
Separation of concerns: Model data is separate from runtime data
Improved stability: Less chance of pod crashes during initialization
Implementation Steps
Create the host directory on your K3s node:
```bash
sudo mkdir -p /opt/ollama/models
sudo chmod 777 /opt/ollama/models  # Ensure permissions are set properly
```
Apply the deployment:
kubectl apply -f ollama-deployment-hostpath.yaml
Verify the pod is running:
kubectl get pods -l app=ollama


Security Considerations for Ollama on Single-Node K3s
For a single-node K3s cluster running Ollama in an air-gapped environment, your current deployment has reasonable security, but there are several improvements you could make.

Current Security Posture
Your deployment has:

Basic container isolation
Resource limits to prevent DoS
Network isolation through Kubernetes service
Air-gapped environment (inherent security advantage)
Security Improvements
Here are security enhancements you could implement:

1. Add Security Context
```bash
spec:
  # ...
  template:
    spec:
      securityContext:
        runAsNonRoot: false  # Ollama typically requires root for now
        runAsUser: 0  # Required for Ollama
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: ollama
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true  # Make root filesystem read-only
          capabilities:
            drop: ["ALL"]  # Drop all capabilities
```
2. Add Network Policy
```bash
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ollama-network-policy
spec:
  podSelector:
    matchLabels:
      app: ollama
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - ports:
    - port: 11434
      protocol: TCP
  egress:
  - {}  # Restrict if needed
```

3. Service Account with Minimal Permissions
```bash
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ollama-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ollama-role
rules: []  # Empty rules - no permissions needed
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ollama-role-binding
subjects:
- kind: ServiceAccount
  name: ollama-sa
roleRef:
  kind: Role
  name: ollama-role
  apiGroup: rbac.authorization.k8s.io
```

And add to your deployment:
```bash
spec:
  template:
    spec:
      serviceAccountName: ollama-sa
```
4. Add Anti-Affinity for Multi-Node Future
```bash
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - ollama
              topologyKey: "kubernetes.io/hostname"
```
5. Resource Quotas for Namespace
```bash
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ollama-quota
spec:
  hard:
    pods: "2"
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "6"
    limits.memory: 12Gi
```

Complete Security-Enhanced Deployment
Here's an updated deployment with all security enhancements:
```bash
apiVersion: v1
kind: Namespace
metadata:
  name: ollama-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ollama-sa
  namespace: ollama-system
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-data
  namespace: ollama-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ollama-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      serviceAccountName: ollama-sa
      securityContext:
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: copy-models
        image: ollama-llama:offline
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "===== Starting init container ====="
            mkdir -p /mnt/ollama
            cp -rp /root/.ollama/* /mnt/ollama/
            echo "Copy operation completed"
        volumeMounts:
        - name: ollama-data
          mountPath: /mnt/ollama
      containers:
      - name: ollama
        image: ollama-llama:offline
        imagePullPolicy: IfNotPresent
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        command: ["/bin/sh", "-c"]
        args:
          - |
            export OLLAMA_NOPRUNE=true
            exec /bin/ollama serve
        env:
        - name: OLLAMA_NOPRUNE
          value: "true"
        - name: GOMEMLIMIT
          value: "5Gi"
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
        - name: tmp-dir
          mountPath: /tmp
        resources:
          limits:
            cpu: "3"
            memory: "6Gi"
          requests:
            cpu: "2"
            memory: "4Gi"
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-data
      - name: tmp-dir
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: ollama-system
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ollama-network-policy
  namespace: ollama-system
spec:
  podSelector:
    matchLabels:
      app: ollama
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - ports:
    - port: 11434
      protocol: TCP
  egress:
  - {}
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ollama-quota
  namespace: ollama-system
spec:
  hard:
    pods: "2"
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "6"
    limits.memory: 12Gi
```

For Air-Gapped Single-Node K3s
For your specific environment (air-gapped, single-node K3s), these are the most important security measures:

Namespace isolation: Put Ollama in its own namespace
Resource limits: Prevent DoS against your node
Network policies: Control what can access Ollama
Host security: Since it's a single node, focus on securing the host
The air-gapped nature already provides significant security benefits by preventing external network access.

Performance Comparison: Models in HostPath vs Containers
Performance Differences
Yes, there are several significant performance differences between storing model files in a hostPath versus inside containers:

HostPath Advantages
No Copy Operations:

HostPath: Models are used directly from the host filesystem
Container: Models must be copied from the container to a PVC during initialization (can take minutes for large models)
Memory Efficiency:

HostPath: No extra memory needed for file copying operations
Container: The copy process can consume significant memory, sometimes causing OOM kills
Pod Startup Time:

HostPath: Nearly instant pod startup since there's no waiting for file copies
Container: Pod startup can take several minutes while models are copied
I/O Performance:

HostPath: Direct access to the host's filesystem, potentially better I/O performance
Container: May involve an extra layer of abstraction if using overlay filesystems
Container Advantages
Portability:

HostPath: Tied to the node where files exist
Container: Self-contained, can run anywhere (at the cost of copy operations)
Isolation:

HostPath: Less isolated from the host system
Container: Better isolation when models are packaged inside the container
Real-world Impact
Based on your logs showing OOM errors during model imports, the hostPath approach is likely to provide significantly better performance for your environment:

Reduced Memory Pressure: Eliminating the multi-GB copy operations will prevent the OOM issues
Faster Restarts: Pod recreation will be much faster
Lower Resource Usage: Your node will have more available resources for actual inference
Best Practice for Your Air-Gapped Setup
For an air-gapped single-node K3s environment running Ollama, the hostPath approach is generally the best choice for performance reasons. Since you don't need the portability benefits of container-embedded models, you get all the performance advantages without significant downsides.

Consider using hostPath for the model files and a small PVC just for runtime state and configuration.