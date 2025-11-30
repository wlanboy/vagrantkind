#!/usr/bin/env bash

# Usage:
#   ./add-dns.sh wsl
#   ./add-dns.sh linux

set -e

TARGET=$1

if [ -z "$TARGET" ]; then
  echo "Bitte Parameter angeben: wsl oder linux"
  exit 1
fi

# IP je nach Umgebung
if [ "$TARGET" = "wsl" ]; then
  IP="172.18.100.10"
elif [ "$TARGET" = "linux" ]; then
  IP="172.18.100.10"
else
  echo "Ungültiger Parameter: $TARGET"
  exit 1
fi

# Einträge
DOMAINS=("argocd.tp.lan" "demo.tp.lan")

for DOMAIN in "${DOMAINS[@]}"; do
  # prüfen ob schon vorhanden
  if grep -q "$DOMAIN" /etc/hosts; then
    echo "$DOMAIN ist bereits in /etc/hosts eingetragen"
  else
    echo "Füge $DOMAIN → $IP hinzu"
    echo "$IP    $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
  fi
done

echo "Fertig. Aktuelle Einträge:"
grep -E "argocd.tp.lan|demo.tp.lan" /etc/hosts
