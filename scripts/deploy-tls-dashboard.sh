#!/bin/bash
################################################################################
# Script to deploy TLS-enabled dashboard with certificate and IngressRoute
#
# This script:
# 1. Creates the TLS certificate
# 2. Creates the HTTPS IngressRoute
# 3. Optionally creates HTTP to HTTPS redirect
# 4. Verifies everything is working
#
# Usage:
#   ./deploy-tls-dashboard.sh <service-name> <namespace> [--with-redirect]
# 
# Example:
#   ./deploy-tls-dashboard.sh traefik kube-system --with-redirect
################################################################################

# Source common functions
source "$(dirname "$0")/common.sh"

# Set up error handling
setup_error_handling

################################################################################
# SECTION: Argument Validation
################################################################################
log "Starting TLS dashboard deployment..."

# Check arguments
if [ $# -lt 2 ]; then
  usage "<service-name> <namespace> [--with-redirect]"
fi

SERVICE_NAME=$1
NAMESPACE=$2
WITH_REDIRECT=${3:-""}

# Check dependencies
check_dependency kubectl "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
check_dependency sed "sed should be available on most systems"

################################################################################
# SECTION: Secret Retrieval
################################################################################
log "SECTION: Retrieving domain configuration from secrets..."

# Wait for infrastructure secrets to be available
wait_for_secret "infrastructure-domains" "infrastructure" 30

# Extract domain values from secret
log "Extracting domain configuration..."
DOMAIN=$(get_secret_value "infrastructure-domains" "infrastructure" "${SERVICE_NAME}-domain")
BASE_DOMAIN=$(get_secret_value "infrastructure-domains" "infrastructure" "base-domain")

if [ -z "$DOMAIN" ] || [ -z "$BASE_DOMAIN" ]; then
  log "ERROR: Could not read domain configuration from secret"
  log "Make sure the sealed secret contains keys: ${SERVICE_NAME}-domain and base-domain"
  exit 1
fi

log "✓ Using domain: $DOMAIN"
log "✓ Using base domain: $BASE_DOMAIN"

################################################################################
# SECTION: Manifest Generation
################################################################################
log ""
log "SECTION: Generating Kubernetes manifests..."

# Create temporary directory for generated manifests
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Generate Certificate manifest
log "Generating Certificate manifest..."
sed -e "s/\${SERVICE_NAME}/$SERVICE_NAME/g" \
    -e "s/\${NAMESPACE}/$NAMESPACE/g" \
    -e "s/\${DOMAIN}/$DOMAIN/g" \
    -e "s/\${BASE_DOMAIN}/$BASE_DOMAIN/g" \
    cluster-setup/cert-manager/templates/dashboard-certificate.yaml > "$TEMP_DIR/certificate.yaml"
log "✓ Certificate manifest generated"

# Generate IngressRoute manifest
log "Generating IngressRoute manifest..."
sed -e "s/\${SERVICE_NAME}/$SERVICE_NAME/g" \
    -e "s/\${NAMESPACE}/$NAMESPACE/g" \
    -e "s/\${DOMAIN}/$DOMAIN/g" \
    cluster-setup/traefik/dashboard/templates/traefik-dashboard-tls.yaml > "$TEMP_DIR/ingressroute.yaml"
log "✓ IngressRoute manifest generated"

################################################################################
# SECTION: Certificate Deployment
################################################################################
log ""
log "SECTION: Deploying TLS Certificate..."

# Apply Certificate
log "Applying Certificate resource..."
apply_manifest "$TEMP_DIR/certificate.yaml" "TLS Certificate for ${SERVICE_NAME}"

# Wait for certificate to be ready
log "Waiting for certificate to be issued (this may take a few minutes)..."
wait_for_resource certificate "${SERVICE_NAME}-dashboard-tls" "$NAMESPACE" 120

# Check certificate status
if ! kubectl get certificate "${SERVICE_NAME}-dashboard-tls" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
  log "ERROR: Certificate not ready. Check with:"
  log "kubectl describe certificate ${SERVICE_NAME}-dashboard-tls -n $NAMESPACE"
  exit 1
fi

log "✓ Certificate successfully issued and ready!"

################################################################################
# SECTION: IngressRoute Deployment
################################################################################
log ""
log "SECTION: Deploying HTTPS IngressRoute..."

# Apply IngressRoute
apply_manifest "$TEMP_DIR/ingressroute.yaml" "HTTPS IngressRoute for ${SERVICE_NAME}"
log "✓ HTTPS IngressRoute deployed"

################################################################################
# SECTION: HTTP to HTTPS Redirect (Optional)
################################################################################
if [ "$WITH_REDIRECT" == "--with-redirect" ]; then
  log ""
  log "SECTION: Setting up HTTP to HTTPS redirect..."
  
  # Generate redirect IngressRoute
  sed -e "s/\${SERVICE_NAME}/$SERVICE_NAME/g" \
      -e "s/\${NAMESPACE}/$NAMESPACE/g" \
      -e "s/\${DOMAIN}/$DOMAIN/g" \
      cluster-setup/traefik/dashboard/templates/traefik-dashboard-redirect.yaml > "$TEMP_DIR/redirect.yaml"
  
  apply_manifest "$TEMP_DIR/redirect.yaml" "HTTP redirect for ${SERVICE_NAME}"
  log "✓ HTTP to HTTPS redirect configured"
fi

################################################################################
# SECTION: Verification and Summary
################################################################################
log ""
log "SECTION: Verifying deployment status..."

# Verify deployment
log "Certificate status:"
kubectl get certificate "${SERVICE_NAME}-dashboard-tls" -n "$NAMESPACE" -o wide

log ""
log "IngressRoute status:"
kubectl get ingressroute "${SERVICE_NAME}-dashboard" -n "$NAMESPACE" -o wide

if [ "$WITH_REDIRECT" == "--with-redirect" ]; then
  log ""
  log "Redirect IngressRoute status:"
  kubectl get ingressroute "${SERVICE_NAME}-dashboard-redirect" -n "$NAMESPACE" -o wide
fi

################################################################################
# SECTION: Success Message
################################################################################
log ""
log "=========================================="
log "SUCCESS: TLS-enabled dashboard deployed!"
log "=========================================="
log ""
log "Dashboard URL: https://${DOMAIN}"
log ""
log "Next steps:"
log "1. Ensure your DNS/hosts file resolves ${DOMAIN} to your LoadBalancer IP"
log "2. Access the dashboard and verify the certificate is valid"
if [ "$WITH_REDIRECT" == "--with-redirect" ]; then
  log "3. Test that http://${DOMAIN} redirects to https://${DOMAIN}"
fi
log ""
log "Troubleshooting:"
log "- Check certificate: kubectl describe certificate ${SERVICE_NAME}-dashboard-tls -n $NAMESPACE"
log "- Check IngressRoute: kubectl describe ingressroute ${SERVICE_NAME}-dashboard -n $NAMESPACE"
log "- View logs: kubectl logs -n cert-manager -l app=cert-manager"
