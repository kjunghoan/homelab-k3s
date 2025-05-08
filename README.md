# Kubernetes Homelab Configuration

This repository contains the configuration for my K3s Kubernetes homelab cluster.

## Architecture

- **K3s Version**: 
- **Nodes**: 1 server node (planned expansion to 3)
- **Network**: MetalLB for LoadBalancer (192.168.1.220-192.168.1.240)
- **Ingress**: Traefik (default from K3s)

## Components

- **cluster-setup/**: Core infrastructure components
- **applications/**: Application deployments
- **scripts/**: Utility scripts

## Installation

See [docs/installation.md](docs/installation.md) for details on setting up a new node.
