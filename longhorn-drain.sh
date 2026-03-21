#!/usr/bin/env bash
set -euo pipefail

NODE="${1:-}"
if [[ -z "$NODE" ]]; then
    read -rp "Node-Name eingeben: " NODE
fi

if ! kubectl get node "$NODE" &>/dev/null; then
    echo "Fehler: Node '$NODE' nicht gefunden"
    exit 1
fi

# Node-IP ermitteln für SSH
NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
if [[ -z "$NODE_IP" ]]; then
    echo "Fehler: Konnte keine IP für Node '$NODE' ermitteln"
    exit 1
fi
echo "Node: $NODE ($NODE_IP)"

# === 1. LONGHORN EVAKUIERUNG ===
echo ""
echo "==> Longhorn: Scheduling deaktivieren und Evakuierung starten..."
kubectl -n longhorn-system patch node.longhorn.io "$NODE" \
    --type=merge \
    -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}'

echo "==> Warte bis alle Longhorn-Replicas vom Node evakuiert sind..."
for i in $(seq 1 120); do
    REPLICAS=$(kubectl -n longhorn-system get replicas.longhorn.io -o json \
        | jq -r --arg node "$NODE" '.items[] | select(.spec.nodeID == $node) | .metadata.name' \
        | wc -l)
    if [[ "$REPLICAS" -eq 0 ]]; then
        echo "Alle Longhorn-Replicas evakuiert."
        break
    fi
    echo "  [$i/120] Noch $REPLICAS Replica(s) auf dem Node – warte 10s..."
    sleep 10
done

REPLICAS=$(kubectl -n longhorn-system get replicas.longhorn.io -o json \
    | jq -r --arg node "$NODE" '.items[] | select(.spec.nodeID == $node) | .metadata.name' \
    | wc -l)
if [[ "$REPLICAS" -gt 0 ]]; then
    echo "Warnung: Noch $REPLICAS Replica(s) auf Node nach 20 Minuten. Fortfahren trotzdem..."
fi

# === 2. CORDON & DRAIN ===
echo ""
echo "==> Cordon Node..."
kubectl cordon "$NODE"

echo "==> Drain Node (ignore daemonsets, delete emptydir data)..."
kubectl drain "$NODE" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=300s

# === 3. OS UPDATE & REBOOT ===
echo ""
echo "==> OS-Update auf $NODE ($NODE_IP)..."
ssh -o StrictHostKeyChecking=no "$NODE_IP" \
    "sudo apt-get update -q && sudo apt-get full-upgrade -y && sudo reboot" || true
# || true weil ssh mit exit-code != 0 beendet wenn reboot die Verbindung trennt

echo ""
echo "=== Drain abgeschlossen ==="
echo "Node '$NODE' ist drainiert und rebootet."
echo "Weiter mit: ./longhorn-undrain.sh $NODE"
