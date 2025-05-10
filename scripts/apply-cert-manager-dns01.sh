#!/bin/bash

################################################################################
# This script applies cert-manager DNS-01 configuration with Cloudflare
#
# Usage:
#   ./apply-cert-manager-dns01.sh
#
# Purpose:
#   - Applies the Cloudflare API token secret
#   - Applies the sealed secret containing ClusterIssuer
#   - Extracts and applies the ClusterIssuer with email substitution
#
# Dependencies:
#   - cert-manager must be installed
#   - sealed-secrets controller must be running
#   - Files must exist:
#     - sealed-secrets/cert-manager/cloudflare-api-token-secret.yaml
#     - sealed-secrets/cert-manager/letsencrypt-dns01-config.yaml
#     - sealed-secrets/cert-manager/letsencrypt-email.yaml
################################################################################

# Source common functions
source "$(dirname "$0")/common.sh"

# Set up error handling
setup_error_handling

# Dependencies
check_dependency kubectl "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
check_dependency base64 "base65 should be available on most systems"

# Ensure cert-manager namespace exists
ensure_namespace cert-manager

# Apply the CF API token secret
apply_manifest "sealed-secrets/cert-manager/cloudflare-api-token-secret.yaml" \
  "Cloudflare API token secret"

# Apply the ClusterIssuer config secret
apply_manifest "sealed-secrets/cert-manager/letsencrypt-dns01-config.yaml" \
  "ClusterIssuer configuration secret"

wait_for_secret "cloudflare-api-token-secret" "cert-manager" 10
wait_for_secret "letsencrypt-dns01-config" "cert-manager" 10

# Get email from secret
log "Extracting email from secret..."
EMAIL=$(get_secret_value "letsencrypt-email" "cert-manager" "email")

if [ -z "$EMAIL" ]; then
  echo "Error: Could not read email from secret"
  exit 1
fi

# Get ClusterIssuer from secret and apply with email substitution
log "Applying ClusterIssuer with email: $EMAIL"
get_secret_value "letsencrypt-dns01-config" "cert-manager" "cluster-issuer.yaml" |
  sed "s/\${LETSENCRYPT_EMAIL}/$EMAIL/" |
  kubectl apply -f -

log "ClusterIssuer successfully applied!"

# Verify the ClusterIssuer was created
log "Verifying ClusterIssuer creation..."
if kubectl get clusterissuer letsencrypt-prod-dns01 -o wide; then
  log "SUCCESS: ClusterIssuer letsencrypt-prod-dns01 is ready"
else
  log "WARNING: ClusterIssuer ist not found or not ready"
  exit 1
fi
