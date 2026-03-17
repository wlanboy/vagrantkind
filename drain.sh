#!/bin/bash
set -euo pipefail

NODE="${1:-}"
if [[ -z "$NODE" ]]; then
    read -rp "Node-Name eingeben: " NODE
fi

if ! kubectl get node "$NODE" &>/dev/null; then
    echo "Fehler: Node '$NODE' nicht gefunden"
    exit 1
fi

echo "Cordon Node: $NODE"
kubectl cordon "$NODE"

echo "Drain Node: $NODE (ignore daemonsets, delete emptydir data)"
kubectl drain "$NODE" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=300s

echo ""
echo "Node '$NODE' ist gedrained. Jetzt Wartung/Reboot durchführen."
echo ""
echo "Danach Node wieder freigeben mit:"
echo "  kubectl uncordon $NODE"
