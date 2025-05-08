# Installation Guide

## Prerequisites
- Ubuntu Server 24.04 LTS
- 4+ CPU cores
- 16+ GB RAM
- 50+ GB disk for OS
- 100+ GB disk for data

## Base System Setup
1. Install Ubuntu Server
2. Format the data disk: `sudo mkfs.ext4 /dev/sdb3`
3. Mount the data disk: `sudo mount /dev/sdb3 /var/lib/rancher`
4. Add to fstab: `echo '/dev/sdb3 /var/lib/rancher ext4 defaults 0 0' | sudo tee -a /etc/fstab`

## K3s Installation
```bash
# Install K3s
curl -sfL https://get.k3s.io | sudo sh -s - server \
  --cluster-init \
  --disable servicelb \
  --tls-san $(hostname -I | awk '{print $1}') \
  --write-kubeconfig-mode 644
```

## Deploy Infrastructure
```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
kubectl apply -f ~/k8s-homelab/cluster-setup/metallb/values.yaml

# Apply Traefik configuration
sudo cp ~/k8s-homelab/cluster-setup/traefik/traefik-config.yaml /var/lib/rancher/k3s/server/manifests/
```

## Test Deployment
```bash
kubectl apply -f ~/k8s-homelab/applications/test-app/nginx.yaml
```
