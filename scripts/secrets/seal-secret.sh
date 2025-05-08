#!/bin/bash
# This script seals a Kubernetes secret and places it in the sealed-secrets directory

# Check if arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 secret-name namespace [key1=value1 key2=value2 ...]"
    echo "Example: $0 my-secret default api-key=1234 password=secret"
    exit 1
fi

SECRET_NAME=$1
NAMESPACE=$2
shift 2

# Create a temporary file for the raw secret
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Create a basic secret manifest
cat > $TEMP_FILE <<EOL
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
stringData:
EOL

# Add each key-value pair
for pair in "$@"; do
    KEY=$(echo $pair | cut -d= -f1)
    VALUE=$(echo $pair | cut -d= -f2-)
    echo "  $KEY: $VALUE" >> $TEMP_FILE
done

# Create the directory for sealed secrets if it doesn't exist
mkdir -p ~/k8s-homelab/sealed-secrets/$NAMESPACE

# Seal the secret
kubeseal --controller-namespace=kube-system --controller-name=sealed-secrets --format yaml < $TEMP_FILE > ~/k8s-homelab/sealed-secrets/$NAMESPACE/$SECRET_NAME.yaml

# Also save the raw secret (for reference, not to be committed)
mkdir -p ~/k8s-homelab/secrets/$NAMESPACE
cp $TEMP_FILE ~/k8s-homelab/secrets/$NAMESPACE/$SECRET_NAME.yaml

echo "Created sealed secret at ~/k8s-homelab/sealed-secrets/$NAMESPACE/$SECRET_NAME.yaml"
echo "Raw secret saved at ~/k8s-homelab/secrets/$NAMESPACE/$SECRET_NAME.yaml (DO NOT COMMIT THIS)"
