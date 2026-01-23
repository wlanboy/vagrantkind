#!/bin/bash
set -euo pipefail

METALLB_VERSION="0.15.2"

# Prüfen ob als root ausgeführt wird (sollte nicht)
if [[ $EUID -eq 0 ]]; then
    echo "Bitte nicht als root ausführen"
    exit 1
fi

# IP ermitteln mit Fehlerprüfung
LOKALE_IP=$(ip a s | grep "inet " | grep "192.168.178." | awk '{print $2}' | cut -d/ -f1)
if [[ -z "$LOKALE_IP" ]]; then
    echo "Fehler: Keine IP im Bereich 192.168.178.x gefunden"
    exit 1
fi
echo "IP: $LOKALE_IP"

# .kube Verzeichnis erstellen falls nicht vorhanden
mkdir -p ~/.kube

# K3s Installation
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
K3S_KUBECONFIG_MODE="644" \
INSTALL_K3S_CHANNEL=stable \
INSTALL_K3S_EXEC="--disable=traefik --node-external-ip=$LOKALE_IP" \
/tmp/k3s-install.sh

# Kubeconfig kopieren
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s.yaml
sudo chown "$USER":"$USER" ~/.kube/k3s.yaml
cp ~/.kube/k3s.yaml ~/.kube/config
sed -i "s/127.0.0.1/$LOKALE_IP/g" ~/.kube/k3s.yaml
sed -i "s/127.0.0.1/$LOKALE_IP/g" ~/.kube/config

# Node-Token sichern
sudo cp /var/lib/rancher/k3s/server/node-token ~/.kube/node-token
sudo chown "$USER":"$USER" ~/.kube/node-token

# Warten bis k3s bereit ist
echo "Warte auf K3s..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# MetalLB installieren
echo "Installing MetalLB (version ${METALLB_VERSION})..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"

echo "Warte auf MetalLB Pods..."
kubectl -n metallb-system wait --for=condition=Ready --all pods --timeout=120s

kubectl apply -f metallb-pool-k3s.yaml
kubectl apply -f metallb-adv.yaml
echo "MetalLB konfiguriert."

# Delete cluster
#sudo /usr/local/bin/k3s-uninstall.sh
