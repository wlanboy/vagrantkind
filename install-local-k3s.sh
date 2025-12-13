#!/bin/bash
set -e

METALLB_VERSION="0.15.2"

LOKALE_IP=$(ip a s | grep "inet " | grep "192.168.178." | awk '{print $2}' | cut -d/ -f1)
echo "IP: $LOKALE_IP"

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_CHANNEL=stable INSTALL_K3S_EXEC="--disable=traefik --node-external-ip=$LOKALE_IP" sh -

sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s.yaml
sudo chown $USER:$USER ~/.kube/k3s.yaml
sed -i "s/127.0.0.1/$LOKALE_IP/" ~/.kube/k3s.yaml

echo "Installing MetalLB (version ${METALLB_VERSION})..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"
echo "MetalLB controller applied."

echo "Applying MetalLB IP address pool configuration..."
kubectl -n metallb-system wait --for=condition=Ready --all pods --timeout 60s
kubectl apply -f metallb-pool-k3s.yaml
kubectl apply -f metallb-adv.yaml
echo "MetalLB IP pools configured."

# Delete cluster
#sudo /usr/local/bin/k3s-uninstall.sh
