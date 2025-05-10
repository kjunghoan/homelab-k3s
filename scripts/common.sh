#!/bin/bash
# Common functions for k3s scripts

# Logging function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if a command is available
check_dependency() {
  local cmd=$1
  local install_hint=$2

  if ! command -v $cmd &>/dev/null; then
    log "ERROR: $cmd is required but not installed."
    if [ -n "$install_hint" ]; then
      echo "$install_hint"
    fi
    exit 1
  fi
}

# Wait for a resource to be ready
wait_for_resource() {
  local resource_type=$1
  local resource_name=$2
  local namespace=${3:-default}
  local timeout=${4:-30}

  log "Waiting for $resource_type/$resource_name in namespace $namespace..."
  kubectl wait --namespace $namespace \
    --for=condition=Ready \
    $resource_type/$resource_name \
    --timeout=${timeout}s
}

# Wait for a secret to exist (sealed secrets take time to decrypt)
wait_for_secret() {
  local secret_name=$1
  local namespace=${2:-default}
  local timeout=${3:-30}
  local elapsed=0

  log "Waiting for secret $secret_name in namespace $namespace..."
  while [ $elapsed -lt $timeout ]; do
    if kubectl get secret $secret_name -n $namespace &> /dev/null; then
      log "Secret $secret_name is now available"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  log "ERROR: Timeout waiting for secret $secret_name after $timeout seconds"
  return 1
}

# Extract data from secret
get_secret_value() {
  local secret_name=$1
  local namespace=$2
  local key=$3

  kubectl get secret $secret_name -n $namespace -o jsonpath="{.data['$key']}" | base64 -d
}

# Apply a yaml manifest with error handling
apply_manifest() {
  local manifest_file=$1
  local description=${2:-"manifest"}

  log "Applying $description..."
  if kubectl apply -f "$manifest_file"; then
    log "Successfully applied $description"
  else
    log "ERROR: Failed to apply $description"
    return 1
  fi
}

# Create a namespace if it doesn't exist
ensure_namespace() {
  local namespace=$1

  if ! kubectl get namespace $namespace &> /dev/null; then
    log "Creating namespace $namespace"
  else
    log "Namespace $namespace already exists"
  fi
}

# Error handler for scripts
setup_error_handling() {
  set -euo pipefail

  handle_error() {
    local exit_code=$?
    local line_number=$1
    local script_name=$(basename "$0")

    log "ERROR in $script_name at line $line_number: Command failed with exit code $exit_code"

    # Cleanup
    if [-n "${TEMP_FILE-}"] && [-f "$TEMP_FILE"]; then
      rm -f "$TEMP_FILE"
    fi

    exit $exit_code
  }
}

# Print script useage and exit
usage() {
  local script_name=$(basename "$0")
  local usage_text=$1

  echo "Usage: $script_name $usage_text"
  exit 1
}

