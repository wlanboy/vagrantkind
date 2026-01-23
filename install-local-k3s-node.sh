#!/bin/bash
set -euo pipefail

# Master-IP als Parameter oder interaktiv
MASTER_IP="${1:-}"
if [[ -z "$MASTER_IP" ]]; then
    read -rp "Master-IP eingeben: " MASTER_IP
fi

# Prüfen ob als root ausgeführt wird
if [[ $EUID -eq 0 ]]; then
    echo "Bitte nicht als root ausführen"
    exit 1
fi

# Lokale IP ermitteln
LOKALE_IP=$(ip a s | grep "inet " | grep "192.168.178." | awk '{print $2}' | cut -d/ -f1)
if [[ -z "$LOKALE_IP" ]]; then
    echo "Fehler: Keine IP im Bereich 192.168.178.x gefunden"
    exit 1
fi
echo "Lokale IP: $LOKALE_IP"

# Node-Token vom Master holen
mkdir -p ~/.kube
echo "Hole Node-Token von $MASTER_IP..."
if ! scp "${MASTER_IP}":~/.kube/node-token ~/.kube/node-token; then
    echo "Fehler: Konnte Node-Token nicht vom Master holen"
    exit 1
fi

NODE_TOKEN=$(cat ~/.kube/node-token)
if [[ -z "$NODE_TOKEN" ]]; then
    echo "Fehler: Node-Token ist leer"
    exit 1
fi

# k3s Agent installieren
echo "Installiere K3s Agent und verbinde mit Master $MASTER_IP..."
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
K3S_URL="https://${MASTER_IP}:6443" \
K3S_TOKEN="${NODE_TOKEN}" \
INSTALL_K3S_CHANNEL=stable \
INSTALL_K3S_EXEC="--node-external-ip=$LOKALE_IP" \
/tmp/k3s-install.sh

echo "Node erfolgreich zum Cluster hinzugefügt."
