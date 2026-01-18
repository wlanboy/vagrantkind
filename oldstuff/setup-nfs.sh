#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
REAL_DIR="/mnt/sata/k8s-backups"
EXPORT_ROOT="/export"
EXPORT_DIR="${EXPORT_ROOT}/k8s-backups"
NETWORK_CIDR="192.168.178.0/24"
EXPORT_OPTIONS="rw,sync,no_subtree_check,no_root_squash"

echo "=== k8s NFSv4 Backup Server Setup (Debian/Ubuntu) ==="

# --- Install NFS server ---
echo "Installing NFS server..."
apt update
apt install -y nfs-kernel-server

# --- Create real directory ---
echo "Creating real directory: $REAL_DIR"
mkdir -p "$REAL_DIR"
chmod 777 "$REAL_DIR"

# --- Create NFSv4 export root ---
echo "Creating NFSv4 export root: $EXPORT_ROOT"
mkdir -p "$EXPORT_ROOT"

# --- Bind mount real directory into NFSv4 root ---
echo "Bind-mounting $REAL_DIR to $EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
mount --bind "$REAL_DIR" "$EXPORT_DIR"

# Persist bind mount
if ! grep -q "$EXPORT_DIR" /etc/fstab; then
    echo "$REAL_DIR $EXPORT_DIR none bind 0 0" >> /etc/fstab
fi

# --- Configure /etc/exports ---
echo "Configuring /etc/exports..."

# Remove old entries
sed -i "\|$REAL_DIR|d" /etc/exports
sed -i "\|$EXPORT_DIR|d" /etc/exports
sed -i "\|$EXPORT_ROOT|d" /etc/exports

# Add NFSv4 root + subdir
echo "$EXPORT_ROOT $NETWORK_CIDR(rw,sync,fsid=0,no_subtree_check,no_root_squash)" >> /etc/exports
echo "$EXPORT_DIR $NETWORK_CIDR($EXPORT_OPTIONS)" >> /etc/exports

# --- Apply export rules ---
exportfs -ra

# --- Enable and start NFS services ---
echo "Starting NFS services..."
systemctl enable --now nfs-server

echo
echo "=== NFSv4 Backup Server Setup Completed ==="
echo "Real directory: $REAL_DIR"
echo "NFSv4 export root: $EXPORT_ROOT"
echo "Exported backup dir: $EXPORT_DIR"
echo "Allowed network: $NETWORK_CIDR"
echo
echo "Backup Target URL:"
echo "nfs://gmk:/k8s-backups"
