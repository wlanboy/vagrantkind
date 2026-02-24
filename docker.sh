#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/whelper.sh"

# Prüfe ob Docker bereits installiert ist
if command -v docker &>/dev/null; then
  echo "  Docker ist bereits installiert ($(docker --version)) -> übersprungen"
else
  echo "  Docker ist nicht installiert -> wird installiert"

  # Add Docker's official GPG key:
  DISTRO_ID=$(. /etc/os-release && echo "$ID")
  DISTRO_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

  sudo apt-get update
  sudo apt-get install -y ca-certificates curl

  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
  fi

  # Add the repository to Apt sources:
  if [ ! -f /etc/apt/sources.list.d/docker.sources ]; then
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${DISTRO_ID}
Suites: ${DISTRO_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  fi

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Erhöhe die Anzahl der inotify-Watches, damit Docker-Container mit vielen Dateien besser funktionieren
grep -qxF "fs.inotify.max_user_instances=512" /etc/sysctl.conf || echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf
grep -qxF "fs.inotify.max_user_watches=65536" /etc/sysctl.conf || echo "fs.inotify.max_user_watches=65536" | sudo tee -a /etc/sysctl.conf
grep -qxF "fs.inotify.max_queued_events=16384" /etc/sysctl.conf || echo "fs.inotify.max_queued_events=16384" | sudo tee -a /etc/sysctl.conf
grep -qxF "vm.max_map_count=262144" /etc/sysctl.conf || echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
grep -qxF "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Stelle sicher, dass der User in der docker-Gruppe ist
if groups "$USER" | grep -q '\bdocker\b'; then
  echo "  $USER ist bereits in der docker-Gruppe -> übersprungen"
else
  echo "  $USER wird zur docker-Gruppe hinzugefügt"
  sudo adduser "$USER" docker
fi
