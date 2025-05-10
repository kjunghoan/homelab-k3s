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

# Apply the Cloudflare API token secret
echo "Applying Cloudflare API token secret..."
kubectl apply -f sealed-secrets/cert-manager/cloudflare-api-token-secret.yaml

# Apply the ClusterIssuer config secret
echo "Applying ClusterIssuer configuration secret..."
kubectl apply -f sealed-secrets/cert-manager/letsencrypt-dns01-config.yaml

# Wait for secrets to be ready
echo "Waiting for secrets to be created..."
sleep 5

# Get email from secret
echo "Extracting email from secret..."
EMAIL=$(kubectl get secret letsencrypt-email -n cert-manager -o jsonpath='{.data.email}' | base64 -d)

if [ -z "$EMAIL" ]; then
    echo "Error: Could not read email from secret"
    exit 1
fi

# Get ClusterIssuer from secret and apply with email substitution
echo "Applying ClusterIssuer with email: $EMAIL"
kubectl get secret letsencrypt-dns01-config -n cert-manager -o jsonpath='{.data.cluster-issuer\.yaml}' | \
  base64 -d | \
  sed "s/\${LETSENCRYPT_EMAIL}/$EMAIL/" | \
  kubectl apply -f -

echo "ClusterIssuer successfully applied!"

# Verify the ClusterIssuer was created
echo "Verifying ClusterIssuer creation..."
kubectl get clusterissuer letsencrypt-prod-dns01 -o wide
