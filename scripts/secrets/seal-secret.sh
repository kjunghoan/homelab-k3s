#!/bin/bash
# This script seals a Kubernetes secret and places it in the sealed-secrets directory

# Check if kubeseal is available
if ! command -v kubeseal &>/dev/null; then
  echo "Error: kubeseal is not installed"
  echo "To install kubeseal, run"
  echo "  # If using homebrew:"
  echo "  brew install kubeseal"
  echo ""
  echo "  # For Linux general:"
  echo "  KUBESEAL_VERSION='' # Set this to latest version"
  echo "  wget \"https://github.com/bitnami-labs/sealed-secrets/releases/download/v\${KUBESEAL_VERSION}/kubeseal-\${KUBESEAL_VERSION}-linux-amd64.tar.gz\""
  echo "  tar -xvzf kubeseal-\${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal"
  echo "  sudo install -m 755 kubeseal /usr/local/bin/kubeseal"
  echo ""
  echo "See https://github.com/bitnami-labs/sealed-secrets#installation for more details"
  exit 1
fi

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
cat >$TEMP_FILE <<EOL
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
  echo "  $KEY: $VALUE" >>$TEMP_FILE
done

# Create the directory for the secret and the sealed secrets if it doesn't exist
mkdir -p ~/k8s-homelab/sealed-secrets/$NAMESPACE
mkdir -p ~/k8s-homelab/secrets/$NAMESPACE

# Seal the secret
kubeseal --controller-namespace=kube-system --controller-name=sealed-secrets --format yaml <$TEMP_FILE >~/k8s-homelab/sealed-secrets/$NAMESPACE/$SECRET_NAME.yaml

# Also save the raw secret (for reference, not to be committed)
cp $TEMP_FILE ~/k8s-homelab/secrets/$NAMESPACE/$SECRET_NAME.yaml

echo "Created sealed secret at ~/k8s-homelab/sealed-secrets/$NAMESPACE/$SECRET_NAME.yaml"
echo "Raw secret saved at ~/k8s-homelab/secrets/$NAMESPACE/$SECRET_NAME.yaml (DO NOT COMMIT THIS)"
