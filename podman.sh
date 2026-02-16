#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/whelper.sh"

# --- Podman + Tools ---
APT_PACKAGES=(podman podman-compose podman-docker slirp4netns uidmap fuse-overlayfs)
MISSING_PKGS=()
for pkg in "${APT_PACKAGES[@]}"; do
  if ! is_apt_installed "$pkg"; then
    MISSING_PKGS+=("$pkg")
  fi
done
if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "  Pakete werden installiert: ${MISSING_PKGS[*]}"
  sudo apt-get update
  sudo apt-get install -y "${MISSING_PKGS[@]}"
else
  echo "  Alle Podman-Pakete sind bereits installiert -> übersprungen"
fi

# --- Rootless: subuid/subgid ---
if grep -q "^${USER}:" /etc/subuid 2>/dev/null; then
  echo "  subuid für $USER ist bereits konfiguriert -> übersprungen"
else
  echo "  subuid/subgid für $USER wird konfiguriert"
  sudo usermod --add-subuids 100000-165535 "$USER"
  sudo usermod --add-subgids 100000-165535 "$USER"
  podman system migrate
fi

# --- Registry-Konfiguration ---
REGISTRIES_CONF="/etc/containers/registries.conf"
if grep -q 'unqualified-search-registries.*docker.io' "$REGISTRIES_CONF" 2>/dev/null; then
  echo "  Registry-Konfiguration ist bereits vorhanden -> übersprungen"
else
  echo "  Registry-Konfiguration wird gesetzt (docker.io, quay.io, ghcr.io)"
  sudo tee -a "$REGISTRIES_CONF" > /dev/null <<'EOF'

# Rootless Podman: Short-Name-Auflösung
unqualified-search-registries = ["docker.io", "quay.io", "ghcr.io"]
EOF
fi

# --- Rootless Storage (fuse-overlayfs) ---
STORAGE_CONF="$HOME/.config/containers/storage.conf"
if [ -f "$STORAGE_CONF" ]; then
  echo "  Storage-Konfiguration ist bereits vorhanden -> übersprungen"
else
  echo "  Storage-Konfiguration wird erstellt (fuse-overlayfs)"
  mkdir -p "$(dirname "$STORAGE_CONF")"
  cat > "$STORAGE_CONF" <<'EOF'
[storage]
driver = "overlay"

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
fi

# --- Rootless Ports: Erlaube Ports ab 80 ---
SYSCTL_CONF="/etc/sysctl.d/99-podman-rootless.conf"
if [ -f "$SYSCTL_CONF" ]; then
  echo "  Sysctl für unprivilegierte Ports ist bereits konfiguriert -> übersprungen"
else
  echo "  Erlaube unprivilegierte Ports ab 80"
  echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee "$SYSCTL_CONF" > /dev/null
  sudo sysctl --system > /dev/null
fi

# --- Rootless Netzwerk: pasta/slirp4netns ---
CONTAINERS_CONF="$HOME/.config/containers/containers.conf"
if [ -f "$CONTAINERS_CONF" ]; then
  echo "  Containers-Konfiguration ist bereits vorhanden -> übersprungen"
else
  echo "  Containers-Konfiguration wird erstellt"
  mkdir -p "$(dirname "$CONTAINERS_CONF")"
  # pasta ist ab Podman 5+ der Standard, Fallback auf slirp4netns
  if podman info --format '{{.Host.Pasta.Executable}}' &>/dev/null 2>&1; then
    NETWORK_BACKEND="pasta"
  else
    NETWORK_BACKEND="slirp4netns"
  fi
  cat > "$CONTAINERS_CONF" <<EOF
[network]
default_rootless_network_cmd = "$NETWORK_BACKEND"

[engine]
# Docker-kompatibles Verhalten für Volume-Berechtigungen
userns = "keep-id"
EOF
  echo "  Netzwerk-Backend: $NETWORK_BACKEND"
fi

# --- Podman-Socket für Docker-Kompatibilität ---
if systemctl --user is-active podman.socket &>/dev/null; then
  echo "  Podman-Socket ist bereits aktiv -> übersprungen"
else
  echo "  Podman-Socket wird aktiviert (Docker-Kompatibilität)"
  systemctl --user enable --now podman.socket
fi

# --- Lingering aktivieren (User-Services laufen ohne Login weiter) ---
if loginctl show-user "$USER" --property=Linger 2>/dev/null | grep -q "yes"; then
  echo "  Linger für $USER ist bereits aktiviert -> übersprungen"
else
  echo "  Linger für $USER wird aktiviert"
  sudo loginctl enable-linger "$USER"
fi

echo ""
echo "  Podman Rootless-Setup abgeschlossen."
echo "  DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock"
