#!/bin/bash

################################################################################
# This script applies cert-manager configuration with email from sealed secrets
#
# Usage:
#   ./apply-cert-manager.sh
#
# Purpose:
#   - Ensures cert-manager namespace exists
#   - Applies sealed secret containing Let's Encrypt email
#   - Extracts email from the secret
#   - Applies ClusterIssuer with the substituted email
#
# Dependencies:
#   - cert-manager must be installed in the cluster
#   - sealed-secrets controller must be running
#   - Files must exist:
#     - sealed-secrets/cert-manager/letsencrypt-email.yaml
#     - cluster-setup/cert-manager/cluster-issuer.yaml
#
# Notes:
#   - The ClusterIssuer template uses ${LETSENCRYPT_EMAIL} placeholder
#   - Email can be updated by modifying the sealed secret
#   - Script includes a 5-second wait for secret to be created
################################################################################

# Ensure cert-manager namespace exists
echo "Creating cert-manager namespace..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# Apply the sealed secret
echo "Applying sealed secret for Let's Encrypt email..."
kubectl apply -f sealed-secrets/cert-manager/letsencrypt-email.yaml

# Wait for secret to be ready
echo "Waiting for secret to be created..."
sleep 5

# Get email from secret
echo "Extracting email from secret..."
EMAIL=$(kubectl get secret letsencrypt-email -n cert-manager -o jsonpath='{.data.email}' | base64 -d)

if [ -z "$EMAIL" ]; then
    echo "Error: Could not read email from secret"
    exit 1
fi

# Apply ClusterIssuer with the email
echo "Applying ClusterIssuer with email: $EMAIL"
cat cluster-setup/cert-manager/cluster-issuer.yaml | \
  sed "s/\${LETSENCRYPT_EMAIL}/$EMAIL/" | \
  kubectl apply -f -

echo "ClusterIssuer successfully applied!"

# Verify the ClusterIssuer was created
echo "Verifying ClusterIssuer creation..."
kubectl get clusterissuer letsencrypt-prod -o wide
