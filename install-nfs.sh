#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
REAL_DIR="/mnt/sata/k8s-backups"
EXPORT_ROOT="/export"
EXPORT_DIR="${EXPORT_ROOT}/k8s-backups"
NETWORK_CIDR="192.168.178.0/24"
EXPORT_OPTIONS="rw,sync,no_subtree_check,no_root_squash"

echo "=== NFSv4 Backup Server Setup ==="

# --- Install NFS server ---
echo "-> Installing NFS server..."
apt update
apt install -y nfs-kernel-server

# --- Create directories ---
echo "-> Creating directories..."
mkdir -p "$REAL_DIR"
chmod 777 "$REAL_DIR"
mkdir -p "$EXPORT_DIR"

# --- Bind mount ---
echo "-> Bind-mounting ${REAL_DIR} -> ${EXPORT_DIR}..."
mount --bind "$REAL_DIR" "$EXPORT_DIR"

if ! grep -q "$EXPORT_DIR" /etc/fstab; then
    echo "$REAL_DIR $EXPORT_DIR none bind 0 0" >> /etc/fstab
fi

# --- Configure /etc/exports ---
echo "-> Configuring /etc/exports..."
sed -i "\|$EXPORT_ROOT|d" /etc/exports
sed -i "\|$EXPORT_DIR|d" /etc/exports

echo "$EXPORT_ROOT $NETWORK_CIDR(rw,sync,fsid=0,no_subtree_check,no_root_squash)" >> /etc/exports
echo "$EXPORT_DIR $NETWORK_CIDR($EXPORT_OPTIONS)" >> /etc/exports

exportfs -ra

# --- Enable and start NFS ---
echo "-> Starting NFS server..."
systemctl enable --now nfs-server

echo
echo "=== Fertig ==="
echo "Export Root   : ${EXPORT_ROOT}"
echo "Backup Dir    : ${EXPORT_DIR}"
echo "Network       : ${NETWORK_CIDR}"
echo "Backup Target : nfs://$(hostname):/${EXPORT_DIR#${EXPORT_ROOT}/}"
