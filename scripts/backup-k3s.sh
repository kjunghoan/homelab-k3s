#!/bin/bash
# Create a snapshot
sudo k3s etcd-snapshot save --name=manual-backup-$(date +%Y-%m-%d)

# List snapshots
echo "Available snapshots:"
sudo k3s etcd-snapshot ls
