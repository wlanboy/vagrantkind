#!/usr/bin/env bash

set -e

echo "=== System aktualisieren ==="
sudo apt update
sudo apt -y upgrade

echo "=== KVM / libvirt / Netzwerk-Pakete installieren ==="
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    libvirt-dev \
    virtinst \
    virt-manager \
    bridge-utils \
    cpu-checker \
    ebtables \
    dnsmasq-base

echo "=== Cloud-Init und Cloud-Image-Tools installieren ==="
sudo apt install -y \
    cloud-init \
    cloud-image-utils \
    genisoimage

echo "=== Prüfen ob KVM unterstützt wird ==="
if kvm-ok >/dev/null 2>&1; then
    echo "OK: Hardware-Virtualisierung ist verfügbar."
else
    echo "WARNUNG: KVM wird nicht unterstützt oder ist deaktiviert."
fi

echo "=== Benutzer zur libvirt- und kvm-Gruppe hinzufügen ==="
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"

echo "=== Cockpit installieren ==="
sudo apt install -y cockpit cockpit-machines

echo "=== Cockpit aktivieren ==="
sudo systemctl enable --now cockpit.socket

echo "=== libvirtd.conf: Socket-Berechtigungen setzen ==="
LIBVIRTD_CONF="/etc/libvirt/libvirtd.conf"
for key in \
    unix_sock_group \
    unix_sock_ro_perms \
    unix_sock_rw_perms \
    unix_sock_admin_perms \
    unix_sock_dir; do
    sudo sed -i "s|^#\s*\(${key}\s*=.*\)|\1|" "$LIBVIRTD_CONF"
done
echo "Fertig – betroffene Zeilen in $LIBVIRTD_CONF:"
grep -E "^(unix_sock_group|unix_sock_ro_perms|unix_sock_rw_perms|unix_sock_admin_perms|unix_sock_dir)" "$LIBVIRTD_CONF"

echo "=== libvirtd aktivieren ==="
sudo systemctl enable --now libvirtd
sudo systemctl daemon-reload
sudo systemctl restart libvirtd

echo "=== Firewall-Regeln setzen (falls UFW aktiv ist) ==="
if sudo ufw status | grep -q "Status: active"; then
    echo "UFW aktiv – öffne Port 9090"
    sudo ufw allow 9090/tcp
else
    echo "UFW ist nicht aktiv – überspringe Firewall-Konfiguration."
fi

echo "=== Fertig! ==="
echo "Starte dein System neu, damit Gruppenrechte aktiv werden."
echo "Cockpit ist erreichbar unter: https://$(hostname -I | awk '{print $1}'):9090"
