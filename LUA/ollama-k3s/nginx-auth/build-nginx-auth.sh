#!/bin/bash
set -e
echo "Building Nginx Auth image for air-gapped environment"
echo "==================================================="

mkdir -p lua

if [ ! -f lua/api-key-auth.lua ]; then
  echo "Creating Lua authentication script..."
  cat > lua/api-key-auth.lua << 'EOF'
local cjson = require "cjson"
local io = require "io"

local function load_api_keys()
    local keys = {}
    local keys_dir = "/etc/api-keys"
    local pfile = io.popen('ls -1 "' .. keys_dir .. '" 2>/dev/null')
    if pfile then
        for filename in pfile:lines() do
            local filepath = keys_dir .. "/" .. filename
            local file = io.open(filepath, "r")
            if file then
                local key = file:read("*all")
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

local function validate_api_key(api_key)
    local valid_keys = load_api_keys()
    for _, valid_key in ipairs(valid_keys) do
        if api_key == valid_key then return true end
    end
    return false
end

local api_key = ngx.req.get_headers()["X-API-Key"]
if not api_key then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "API key required"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

if not validate_api_key(api_key) then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "Invalid API key"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

ngx.req.set_header("X-API-Key", api_key)
EOF
fi

if [ ! -f nginx.conf ]; then
  echo "Creating Nginx configuration..."
  cat > nginx.conf << 'EOF'
worker_processes auto;
events { worker_connections 1024; }
http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    include /etc/nginx/conf.d/*.conf;
}
EOF
fi

# Get the hostname before creating default.conf
HOSTNAME=$(hostname)
echo "Using hostname: $HOSTNAME"

if [ ! -f default.conf ]; then
  echo "Creating default server configuration..."
  cat > default.conf << EOF
lua_package_path '/etc/nginx/lua/?.lua;;';
server {
    listen 80;
    server_name ${HOSTNAME};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name ${HOSTNAME};
    ssl_certificate /etc/nginx/ssl/tls.crt;
    ssl_certificate_key /etc/nginx/ssl/tls.key;
    location / {
        access_by_lua_file /etc/nginx/lua/api-key-auth.lua;
        proxy_pass http://ollama:11434;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 600;
        proxy_send_timeout 600;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 0;
    }
}
EOF
fi

if [ ! -f Dockerfile ]; then
  echo "Creating Dockerfile..."
  cat > Dockerfile << 'EOF'
FROM openresty/openresty:focal
RUN luarocks install lua-cjson
RUN mkdir -p /etc/nginx/lua
COPY lua/api-key-auth.lua /etc/nginx/lua/
RUN chmod -R 755 /etc/nginx/lua
RUN mkdir -p /etc/nginx/conf.d
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
RUN mkdir -p /var/log/nginx/ && touch /var/log/nginx/error.log && touch /var/log/nginx/access.log
EXPOSE 80 443
CMD ["openresty", "-g", "daemon off;"]
EOF
fi

echo "Building Docker image..."
docker build -t nginx-auth:offline .
echo "Saving image to tar file..."
docker save nginx-auth:offline -o nginx-auth-offline.tar
echo "Build complete. Image saved as nginx-auth-offline.tar"
echo "To import into K3s: sudo k3s ctr images import nginx-auth-offline.tar"
