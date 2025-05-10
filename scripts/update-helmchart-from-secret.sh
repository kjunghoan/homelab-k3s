#!/bin/bash

################################################################################
# This script reads a secret's values and updates any HelmChartConfig when run
# This emulates environment variable substitution (${VAR}) which HelmChartConfig
# doesn't support natively
#
# Usage:
#   ./update-helmchart-from-secret.sh <helmchart-name> <secret-name> <namespace>
#
# Arguments:
#   helmchart-name  - Name of the HelmChartConfig to update
#   secret-name     - Name of the secret containing values
#   namespace       - Kubernetes namespace
#
# Example:
#   ./update-helmchart-from-secret.sh traefik traefik-config-values kube-system
################################################################################

# Source common functions
source "$(dirname "$0")/common.sh"

# Set up error handling
setup_error_handling

# Check if arguments are provided
if [ $# -lt 3 ]; then
  usage "<helmchart-name> <secret-name> <namespace> [secret-key]"
fi

HELMCHART_NAME=$1
SECRET_NAME=$2
NAMESPACE=$3
SECRET_KEY=${4:-values.yaml}

check_dependency kubectl "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"

wait_for_secret "$SECRET_NAME" "$NAMESPACE" 10

# Extract the values from the secret
echo "Reading values from secret ${SECRET_NAME}..."
VALUES=$(get_secret_value "$SECRET_NAME" "$NAMESPACE" "$SECRET_KEY")

if [ -z "$VALUES" ]; then
  log "Error: Could not read values from secret ${SECRET_NAME}"
  exit 1
fi

# Create a temporary HelmChartConfig with the values inline
TEMP_FILE=$(mktemp)
cat <<EOF >"$TEMP_FILE"
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: ${HELMCHART_NAME}
  namespace: ${NAMESPACE}
spec:
  valuesContent: |-
$(echo "$VALUES" | sed 's/^/    /')
EOF

# Apply the updated HelmChartConfig
log "Applying updated configuration for ${HELMCHART_NAME}..."
apply_manifest "$TEMP_FILE" "HelpChartConfig" "${HELMCHART_NAME}"

# Clean up
rm -f $TEMP_FILE

log "SUCCESS: updated ${HELMCHART_NAME} configuration from secret ${SECRET_NAME}"
