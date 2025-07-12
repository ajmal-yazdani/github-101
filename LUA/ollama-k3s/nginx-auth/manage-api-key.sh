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
    echo "Error: No API key provided"; show_help; exit 1
  fi
  local key_name="key$(date +%s)"
  kubectl patch secret api-keys -n nginx --type=json -p="[{\"op\": \"add\", \"path\": \"/data/$key_name\", \"value\": \"$(echo -n "$new_key" | base64)\"}]"
  echo "API key added successfully"
  kubectl rollout restart deployment nginx-auth -n nginx
}

function remove_key {
  local key_to_remove="$1"
  if [ -z "$key_to_remove" ]; then
    echo "Error: No API key provided"; show_help; exit 1
  fi
  local key_name=""
  while IFS=: read -r name value; do
    if [ "$value" == "$key_to_remove" ]; then key_name="$name"; break; fi
  done < <(get_api_keys)
  if [ -z "$key_name" ]; then echo "Error: API key not found"; return; fi
  kubectl patch secret api-keys -n nginx --type=json -p="[{\"op\": \"remove\", \"path\": \"/data/$key_name\"}]"
  echo "API key removed successfully"
  kubectl rollout restart deployment nginx-auth -n nginx
}

case "$1" in
  add) add_key "$2" ;;
  remove) remove_key "$2" ;;
  list) list_keys ;;
  *) show_help ;;
esac
