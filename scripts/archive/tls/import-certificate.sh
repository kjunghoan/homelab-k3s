#!/bin/bash

# Script to import certificate into Kubernetes with proper labels
CERT_FILE=/home/kjunghoan/k8s-homelab/secrets/tls/fullchain4.pem
KEY_FILE=/home/kjunghoan/k8s-homelab/secrets/tls/privkey4.pem
SECRET_NAME="kjunghoan-com-tls"

# Create the certificate secret with labels
kubectl create secret tls $SECRET_NAME \
    --cert="$CERT_FILE" \
    --key="$KEY_FILE" \
    --namespace=kube-system \
    --dry-run=client -o yaml > cert-secret.yaml

# Add labels to the secret
kubectl label --local -f cert-secret.yaml \
    tier=ingress \
    managed-by=sealed-secret \
    environment=infrastructure \
    component=tls-certificate \
    domain=kjunghoan.com \
    --dry-run=client -o yaml > labeled-cert-secret.yaml

# Seal the labeled certificate secret
kubeseal --controller-namespace=kube-system --controller-name=sealed-secrets \
    --format yaml < labeled-cert-secret.yaml > ~/k8s-homelab/sealed-secrets/kube-system/$SECRET_NAME.yaml

# Clean up temp files
rm cert-secret.yaml labeled-cert-secret.yaml

echo "Certificate imported successfully with labels!"
echo "Sealed secret created at: ~/k8s-homelab/sealed-secrets/kube-system/$SECRET_NAME.yaml"
