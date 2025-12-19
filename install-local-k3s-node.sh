#!/bin/bash

# IP des Masters (der erste Node)
MASTER_IP="192.168.178.91"

# Lokale IP des zweiten Nodes
LOKALE_IP=$(ip a s | grep "inet " | grep "192.168.178." | awk '{print $2}' | cut -d/ -f1)
echo "Lokale IP: $LOKALE_IP"

# Node-Token vom Master holen
mkdir -p ~/.kube
scp ${MASTER_IP}:~/.kube/node-token ~/.kube/node-token

NODE_TOKEN=$(cat ~/.kube/node-token)

# k3s Agent installieren und mit Master verbinden
curl -sfL https://get.k3s.io | \
  K3S_URL="https://${MASTER_IP}:6443" \
  K3S_TOKEN="${NODE_TOKEN}" \
  INSTALL_K3S_CHANNEL=stable \
  INSTALL_K3S_EXEC="--node-external-ip=$LOKALE_IP" \
  sh -

echo "Node erfolgreich zum Cluster hinzugefügt."
