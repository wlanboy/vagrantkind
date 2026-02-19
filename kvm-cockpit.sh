#!/usr/bin/env bash

set -e

echo "=== Cockpit installieren ==="
sudo apt install -y cockpit cockpit-machines

echo "=== Cockpit aktivieren ==="
sudo systemctl enable --now cockpit.socket

echo "=== Firewall-Regeln setzen (falls UFW aktiv ist) ==="
if sudo ufw status | grep -q "Status: active"; then
    echo "UFW aktiv – öffne Port 9090"
    sudo ufw allow 9090/tcp
else
    echo "UFW ist nicht aktiv – überspringe Firewall-Konfiguration."
fi

echo "=== Fertig! ==="
echo "Cockpit ist erreichbar unter: https://$(hostname -I | awk '{print $1}'):9090"
