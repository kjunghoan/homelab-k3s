#!/bin/bash
# set -x

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

# Check if arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 helmchart-name secret-name namespace [secret-key]"
    echo "Example: $0 traefik traefik-config-values kube-system"
    echo "Secret key defaults to 'values.yaml' if not provided"
    exit 1
fi

HELMCHART_NAME=$1
SECRET_NAME=$2
NAMESPACE=$3
SECRET_KEY=${4:-values.yaml}

# Escape sequence for secret key of jsonpath:
ESCAPED_SECRET_KEY=$(echo "${SECRET_KEY}" | sed 's/\./\\./g')

# Extract the values from the secret
echo "Reading values from secret ${SECRET_NAME}..."
VALUES=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath="{.data.${ESCAPED_SECRET_KEY}}" | base64 -d)

# debug: check the value
# echo "DEBUG: VALUES len: ${#VALUES}"

if [ -z "$VALUES" ]; then
    echo "Error: Could not read values from secret ${SECRET_NAME}"
    exit 1
fi

# echo "read values from secert"

# Create a temporary HelmChartConfig with the values inline
cat <<EOF > /tmp/${HELMCHART_NAME}-config.yaml
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
echo "Applying updated configuration for ${HELMCHART_NAME}..."
kubectl apply -f /tmp/${HELMCHART_NAME}-config.yaml

# Clean up
rm /tmp/${HELMCHART_NAME}-config.yaml

echo "Successfully updated ${HELMCHART_NAME} configuration from secret ${SECRET_NAME}"
