#!/bin/bash
################################################################################
# Script to set up automated certificate for a dashboard
#
# This script:
# 1. Creates a Certificate resource for specified domain
# 2. Updates the IngressRoute to use the automated certificate
# 3. Verifies the certificate is issued correctly
#
# Usage:
#   ./setup-dashboard-cert.sh <domain> <service-name> <namespace>
################################################################################

# Source common functions
source "$(dirname "$0")/common.sh"

# Set up error handling
setup_error_handling

# Check arguments
if [ $# -lt 3 ]; then
  usage "<domain> <service-name> <namespace>"
fi

DOMAIN=$1
SERVICE_NAME=$2
NAMESPACE=$3

# Check dependencies
check_dependency kubectl "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
check_dependency jq "Please install jq: https://stedolan.github.io/jq/download/"

# Create Certificate resource
log "Creating Certificate resource for ${DOMAIN}..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${SERVICE_NAME}-dashboard-tls
  namespace: ${NAMESPACE}
spec:
  secretName: ${SERVICE_NAME}-dashboard-tls
  issuerRef:
    name: letsencrypt-prod-dns01
    kind: ClusterIssuer
  commonName: ${DOMAIN}
  dnsNames:
  - ${DOMAIN}
EOF

# Wait for certificate to be ready
log "Waiting for certificate to be issued..."
wait_for_resource certificate "${SERVICE_NAME}-dashboard-tls" "$NAMESPACE" 120

# Check certificate status
log "Checking certificate status..."
if kubectl get certificate "${SERVICE_NAME}-dashboard-tls" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
  log "SUCCESS: Certificate is ready"
else
  log "WARNING: Certificate may not be ready yet. Check with:"
  log "kubectl get certificate ${SERVICE_NAME}-dashboard-tls -n $NAMESPACE -o wide"
  log "kubectl describe certificate ${SERVICE_NAME}-dashboard-tls -n $NAMESPACE"
fi

# Update IngressRoute (if it exists)
log "Checking for existing IngressRoute..."
if kubectl get ingressroute "${SERVICE_NAME}-dashboard" -n "$NAMESPACE" &>/dev/null; then
  log "Found existing IngressRoute. Updating to use new certificate..."

  # Backup current IngressRoute
  kubectl get ingressroute "${SERVICE_NAME}-dashboard" -n "$NAMESPACE" -o yaml >"${SERVICE_NAME}-ingressroute-backup.yaml"

  # Patch the IngressRoute to use the new certificate
  kubectl patch ingressroute "${SERVICE_NAME}-dashboard" -n "$NAMESPACE" --type='merge' -p "
    spec:
      tls:
        secretName: ${SERVICE_NAME}-dashboard-tls
    "

  log "IngressRoute updated. Backup saved to ${SERVICE_NAME}-ingressroute-backup.yaml"
else
  log "No IngressRoute found for ${SERVICE_NAME}-dashboard"
  log "You may need to create or update it manually to use the certificate"
fi

log "Certificate setup complete!"
log "Monitor certificate status with:"
log "kubectl get certificate ${SERVICE_NAME}-dashboard-tls -n $NAMESPACE -w"
