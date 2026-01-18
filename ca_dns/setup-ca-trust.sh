#!/bin/bash
set -euo pipefail

DNS_SERVER="${1:-192.168.178.91}"
RESOLVED_CONF="/etc/systemd/resolved.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prüfen ob CA-Dateien existieren
for cert in ca-gmk.pem ca-gmkc.pem; do
    if [[ ! -f "$SCRIPT_DIR/$cert" ]]; then
        echo "Fehler: $cert nicht gefunden in $SCRIPT_DIR"
        exit 1
    fi
done

# --- DNS in /etc/systemd/resolved.conf setzen ---
echo "Passe DNS-Eintrag in $RESOLVED_CONF an (DNS=$DNS_SERVER)..."

if grep -q "^#DNS=" "$RESOLVED_CONF"; then
    sudo sed -i "s/^#DNS=.*/DNS=$DNS_SERVER/" "$RESOLVED_CONF"
elif grep -q "^DNS=" "$RESOLVED_CONF"; then
    sudo sed -i "s/^DNS=.*/DNS=$DNS_SERVER/" "$RESOLVED_CONF"
else
    echo "DNS=$DNS_SERVER" | sudo tee -a "$RESOLVED_CONF" >/dev/null
fi

echo "Starte systemd-resolved neu..."
sudo systemctl daemon-reload
sudo systemctl restart systemd-resolved

# --- CA-Zertifikate installieren ---
echo "Installiere CA-Zertifikate..."

sudo cp "$SCRIPT_DIR/ca-gmk.pem" /usr/local/share/ca-certificates/ca-gmk.crt
sudo cp "$SCRIPT_DIR/ca-gmkc.pem" /usr/local/share/ca-certificates/ca-gmkc.crt

echo "Aktualisiere Zertifikatsspeicher..."
sudo update-ca-certificates

echo "Fertig!"
