#!/bin/bash

set -e

# --- DNS in /etc/systemd/resolved.conf setzen ---
RESOLVED_CONF="/etc/systemd/resolved.conf"

echo "Passe DNS-Eintrag in $RESOLVED_CONF an..."

# Falls Zeile existiert, ersetzen – sonst hinzufügen
if grep -q "^#DNS=" "$RESOLVED_CONF"; then
    sudo sed -i 's/^#DNS=.*/DNS=192.168.178.91/' "$RESOLVED_CONF"
elif grep -q "^DNS=" "$RESOLVED_CONF"; then
    sudo sed -i 's/^DNS=.*/DNS=192.168.178.91/' "$RESOLVED_CONF"
else
    echo "DNS=192.168.178.91" | sudo tee -a "$RESOLVED_CONF" >/dev/null
fi

echo "Starte systemd-resolved neu..."
sudo systemctl daemon-reload
sudo systemctl restart systemd-resolved

# --- CA-Zertifikate installieren ---
echo "Installiere CA-Zertifikate..."

sudo cp ca-gmk.pem /usr/local/share/ca-certificates/ca-gmk.crt
sudo cp ca-gmkc.pem /usr/local/share/ca-certificates/ca-gmkc.crt

echo "Aktualisiere Zertifikatsspeicher..."
sudo update-ca-certificates

echo "Fertig!"
