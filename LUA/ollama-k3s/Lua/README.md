## API Key Authentication for Ollama with Kubernetes Secrets

# Step 1: Create Dockerfile for OpenResty with API Key Authentication
```bash
FROM openresty/openresty:focal

# Install required Lua modules
RUN luarocks install lua-cjson

# Create directories for Lua scripts
RUN mkdir -p /etc/nginx/lua

# Copy Lua authentication script
COPY lua/api-key-auth.lua /etc/nginx/lua/

# Set permissions
RUN chmod -R 755 /etc/nginx/lua

# Create Nginx configuration
RUN mkdir -p /etc/nginx/conf.d
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Create necessary directories and files for Nginx
RUN mkdir -p /var/log/nginx/ && \
    touch /var/log/nginx/error.log && \
    touch /var/log/nginx/access.log

# Expose ports
EXPOSE 80 443

# Start Nginx
CMD ["openresty", "-g", "daemon off;"]
```

# Step 2: Create Lua Authentication Script Using Mounted Secrets
```bash
local cjson = require "cjson"
local io = require "io"

-- Load API keys from mounted Kubernetes secret
local function load_api_keys()
    local keys = {}
    local keys_dir = "/etc/api-keys"
    
    -- List files in the directory
    local pfile = io.popen('ls -1 "' .. keys_dir .. '" 2>/dev/null')
    if pfile then
        for filename in pfile:lines() do
            local filepath = keys_dir .. "/" .. filename
            local file = io.open(filepath, "r")
            if file then
                local key = file:read("*all")
                -- Trim any whitespace
                key = key:gsub("^%s*(.-)%s*$", "%1")
                if key and key ~= "" then
                    table.insert(keys, key)
                end
                file:close()
            end
        end
        pfile:close()
    end
    
    return keys
end

-- API key validation function
local function validate_api_key(api_key)
    local valid_keys = load_api_keys()
    
    for _, valid_key in ipairs(valid_keys) do
        if api_key == valid_key then
            return true
        end
    end
    
    return false
end

-- Main execution
local api_key = ngx.req.get_headers()["X-API-Key"]
if not api_key then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "API key required"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- Validate API key
if not validate_api_key(api_key) then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "Invalid API key"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- If we reach here, API key is valid
ngx.req.set_header("X-API-Key", api_key)
```
# Step 3: Create Nginx Configuration Files
```bash
worker_processes auto;
events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    sendfile        on;
    keepalive_timeout  65;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Include server configurations
    include /etc/nginx/conf.d/*.conf;
}

lua_package_path '/etc/nginx/lua/?.lua;;';

server {
    listen 80;
    server_name k3s-airgap;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name k3s-airgap;
    
    ssl_certificate /etc/nginx/ssl/tls.crt;
    ssl_certificate_key /etc/nginx/ssl/tls.key;
    
    location / {
        access_by_lua_file /etc/nginx/lua/api-key-auth.lua;
        
        proxy_pass http://ollama:11434;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        proxy_read_timeout 600;
        proxy_send_timeout 600;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 0;
    }
}
```
# Step 4: Create Build and Deploy Scripts
```bash
#!/bin/bash
set -e

echo "Building Nginx Auth image for air-gapped environment"
echo "==================================================="

# Create directories if they don't exist
mkdir -p lua

# Create Lua authentication script if it doesn't exist
if [ ! -f lua/api-key-auth.lua ]; then
  echo "Creating Lua authentication script..."
  cat > lua/api-key-auth.lua << 'EOF'
local cjson = require "cjson"
local io = require "io"

-- Load API keys from mounted Kubernetes secret
local function load_api_keys()
    local keys = {}
    local keys_dir = "/etc/api-keys"
    
    -- List files in the directory
    local pfile = io.popen('ls -1 "' .. keys_dir .. '" 2>/dev/null')
    if pfile then
        for filename in pfile:lines() do
            local filepath = keys_dir .. "/" .. filename
            local file = io.open(filepath, "r")
            if file then
                local key = file:read("*all")
                -- Trim any whitespace
                key = key:gsub("^%s*(.-)%s*$", "%1")
                if key and key ~= "" then
                    table.insert(keys, key)
                end
                file:close()
            end
        end
        pfile:close()
    end
    
    return keys
end

-- API key validation function
local function validate_api_key(api_key)
    local valid_keys = load_api_keys()
    
    for _, valid_key in ipairs(valid_keys) do
        if api_key == valid_key then
            return true
        end
    end
    
    return false
end

-- Main execution
local api_key = ngx.req.get_headers()["X-API-Key"]
if not api_key then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "API key required"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- Validate API key
if not validate_api_key(api_key) then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "Invalid API key"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- If we reach here, API key is valid
ngx.req.set_header("X-API-Key", api_key)
EOF
fi

# Create Nginx configuration
if [ ! -f nginx.conf ]; then
  echo "Creating Nginx configuration..."
  cat > nginx.conf << 'EOF'
worker_processes auto;
events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    sendfile        on;
    keepalive_timeout  65;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Include server configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF
fi

if [ ! -f default.conf ]; then
  echo "Creating default server configuration..."
  cat > default.conf << 'EOF'
lua_package_path '/etc/nginx/lua/?.lua;;';

server {
    listen 80;
    server_name k3s-airgap;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name k3s-airgap;
    
    ssl_certificate /etc/nginx/ssl/tls.crt;
    ssl_certificate_key /etc/nginx/ssl/tls.key;
    
    location / {
        access_by_lua_file /etc/nginx/lua/api-key-auth.lua;
        
        proxy_pass http://ollama:11434;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        proxy_read_timeout 600;
        proxy_send_timeout 600;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 0;
    }
}
EOF
fi

# Create Dockerfile if it doesn't exist
if [ ! -f Dockerfile ]; then
  echo "Creating Dockerfile..."
  cat > Dockerfile << 'EOF'
FROM openresty/openresty:focal

# Install required Lua modules
RUN luarocks install lua-cjson

# Create directories for Lua scripts
RUN mkdir -p /etc/nginx/lua

# Copy Lua authentication script
COPY lua/api-key-auth.lua /etc/nginx/lua/

# Set permissions
RUN chmod -R 755 /etc/nginx/lua

# Create Nginx configuration
RUN mkdir -p /etc/nginx/conf.d
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Create necessary directories and files for Nginx
RUN mkdir -p /var/log/nginx/ && \
    touch /var/log/nginx/error.log && \
    touch /var/log/nginx/access.log

# Expose ports
EXPOSE 80 443

# Start Nginx
CMD ["openresty", "-g", "daemon off;"]
EOF
fi

# Build the image
echo "Building Docker image..."
docker build -t nginx-auth:offline .

# Save the image to a tar file
echo "Saving image to tar file..."
docker save nginx-auth:offline -o nginx-auth-offline.tar

echo "Build complete. Image saved as nginx-auth-offline.tar"
echo "To import into K3s: sudo k3s ctr images import nginx-auth-offline.tar"

#!/bin/bash
set -e

echo "Deploying Nginx Auth in air-gapped K3s with Kubernetes Secrets"
echo "============================================================="

# Create namespace if it doesn't exist
kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f -

# Create API key secret
echo "Creating API key secret..."
cat > api-keys.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
  namespace: nginx
type: Opaque
stringData:
  key1: "12345"
  key2: "secret-key-2"
  key3: "secret-key-3"
EOF

kubectl apply -f api-keys.yaml

# Create TLS certificate secret if it doesn't exist
if ! kubectl get secret -n nginx ollama-tls-cert-host &> /dev/null; then
  echo "Generating TLS certificate..."
  
  # Get the hostname
  HOST=$(hostname -f)
  if [ -z "$HOST" ]; then
    echo "Using 'hostname' command output instead..."
    HOST=$(hostname)
  fi
  
  echo "Using hostname: $HOST"
  
  # Create directory for certificates
  mkdir -p ~/certs && cd ~/certs
  
  # Generate private key
  openssl genrsa -out tls.key 2048
  
  # Create OpenSSL config
  cat > openssl.cnf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = US
ST = State
L = City
O = Organization
OU = OrganizationalUnit
CN = ${HOST}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HOST}
EOF
  
  # Generate CSR and self-signed certificate
  openssl req -new -key tls.key -out tls.csr -config openssl.cnf
  openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt \
    -extensions req_ext -extfile openssl.cnf
  
  # Create Kubernetes secret
  kubectl create secret tls ollama-tls-cert-host --cert=tls.crt --key=tls.key -n nginx
  
  cd -
fi

# Create deployment and service for Nginx auth
cat > nginx-auth-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-auth
  namespace: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-auth
  template:
    metadata:
      labels:
        app: nginx-auth
    spec:
      containers:
      - name: nginx-auth
        image: nginx-auth:offline
        ports:
        - containerPort: 80
        - containerPort: 443
        volumeMounts:
        - name: tls-certs
          mountPath: /etc/nginx/ssl
        - name: api-keys
          mountPath: /etc/api-keys
          readOnly: true
      volumes:
      - name: tls-certs
        secret:
          secretName: ollama-tls-cert-host
      - name: api-keys
        secret:
          secretName: api-keys
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-auth
  namespace: nginx
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: 30080
  - name: https
    port: 443
    targetPort: 443
    nodePort: 30443
  selector:
    app: nginx-auth
EOF

# Apply the deployment
kubectl apply -f nginx-auth-deployment.yaml

# Update the ingress to use the new auth service
cat > ollama-ingress-auth.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ollama-ingress
  namespace: nginx
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - k3s-airgap
    secretName: ollama-tls-cert-host
  rules:
  - host: k3s-airgap
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-auth
            port:
              number: 443
EOF

# Apply the ingress
kubectl apply -f ollama-ingress-auth.yaml

echo "Waiting for deployment to be ready..."
kubectl rollout status deployment nginx-auth -n nginx

echo "Deployment complete!"
echo "You can now access the API using:"
echo "curl -H \"X-API-Key: 12345\" -k https://k3s-airgap/api/version"
```

# Step 5: Create API Key Management Script
```bash
#!/bin/bash
set -e

function show_help {
  echo "API Key Management Script with Kubernetes Secrets"
  echo "-----------------------------------------------"
  echo "Usage:"
  echo "  $0 add KEY       # Add a new API key"
  echo "  $0 remove KEY    # Remove an API key"
  echo "  $0 list          # List current API keys"
}

function get_api_keys {
  kubectl get secret api-keys -n nginx -o json | jq -r '.data | keys[] as $k | "\($k):\((.[$k] | @base64d))"'
}

function list_keys {
  echo "Current API keys:"
  get_api_keys | awk -F: '{print $2}'
}

function add_key {
  local new_key="$1"
  if [ -z "$new_key" ]; then
    echo "Error: No API key provided"
    show_help
    exit 1
  fi
  
  # Generate a unique key name
  local key_name="key$(date +%s)"
  
  # Add the key to the secret
  kubectl patch secret api-keys -n nginx --type=json -p="[{\"op\": \"add\", \"path\": \"/data/$key_name\", \"value\": \"$(echo -n "$new_key" | base64)\"}]"
  
  echo "API key added successfully"
  
  # Restart the deployment to ensure it picks up the new key
  kubectl rollout restart deployment nginx-auth -n nginx
}

function remove_key {
  local key_to_remove="$1"
  if [ -z "$key_to_remove" ]; then
    echo "Error: No API key provided"
    show_help
    exit 1
  fi
  
  # Find key name by value
  local key_name=""
  while IFS=: read -r name value; do
    if [ "$value" == "$key_to_remove" ]; then
      key_name="$name"
      break
    fi
  done < <(get_api_keys)
  
  if [ -z "$key_name" ]; then
    echo "Error: API key not found"
    return
  fi
  
  # Remove the key from the secret
  kubectl patch secret api-keys -n nginx --type=json -p="[{\"op\": \"remove\", \"path\": \"/data/$key_name\"}]"
  
  echo "API key removed successfully"
  
  # Restart the deployment to ensure it picks up the change
  kubectl rollout restart deployment nginx-auth -n nginx
}

# Main script execution
case "$1" in
  add)
    add_key "$2"
    ;;
  remove)
    remove_key "$2"
    ;;
  list)
    list_keys
    ;;
  *)
    show_help
    ;;
esac
```

# Step 6: Execute the Build and Deploy Process
```bash
# Step 1: Run the build script to create the Docker image
chmod +x build-nginx-auth.sh
./build-nginx-auth.sh

# Step 2: Import the image into K3s (may need sudo)
sudo k3s ctr images import nginx-auth-offline.tar

# Step 3: Deploy the Nginx auth service
chmod +x deploy-nginx-auth.sh
./deploy-nginx-auth.sh

# Step 4: Test the deployment
curl -H "X-API-Key: 12345" -k https://k3s-airgap/api/version
```

Benefits of Using Kubernetes Secrets:
Secure Storage: API keys are stored securely in Kubernetes secrets
No Hardcoding: No API keys are hardcoded in scripts or images
Dynamic Management: Keys can be added/removed without rebuilding images
Access Control: Kubernetes RBAC can control who can manage API keys
Secret Rotation: Keys can be rotated without service disruption
This implementation provides a secure and flexible way to manage API keys for your Ollama service in an air-gapped K3s environment.