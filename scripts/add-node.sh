#!/bin/bash
# Get token from server
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "To add a new server node to the cluster, run this on the new node:"
echo "curl -sfL https://get.k3s.io | sudo sh -s - server --server https://${SERVER_IP}:6443 --token ${NODE_TOKEN}"

echo "To add a new agent node to the cluster, run this on the new node:"
echo "curl -sfL https://get.k3s.io | sudo sh -s - agent --server https://${SERVER_IP}:6443 --token ${NODE_TOKEN}"
