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
echo "Node: $NODE"

# === 1. WARTEN BIS READY ===
echo ""
echo "==> Warte auf Node Ready..."
for i in $(seq 1 60); do
    STATUS=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [[ "$STATUS" == "True" ]]; then
        echo "Node ist Ready."
        break
    fi
    echo "  [$i/60] Status: $STATUS – warte 10s..."
    sleep 10
done

STATUS=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
if [[ "$STATUS" != "True" ]]; then
    echo "Fehler: Node ist nach 10 Minuten nicht Ready. Bitte manuell prüfen."
    echo "Uncordon:           kubectl uncordon $NODE"
    echo "Longhorn re-enable: kubectl -n longhorn-system patch node.longhorn.io $NODE --type=merge -p '{\"spec\":{\"allowScheduling\":true,\"evictionRequested\":false}}'"
    exit 1
fi

# Istio-Sidecars brauchen kurz bis sie injiziert und Ready sind
echo "==> Warte 15s damit Istio-Sidecars starten können..."
sleep 15

# === 2. UNCORDON ===
echo "==> Uncordon Node..."
kubectl uncordon "$NODE"

# === 3. LONGHORN SCHEDULING REAKTIVIEREN ===
echo "==> Longhorn: Scheduling wieder aktivieren..."
kubectl -n longhorn-system patch node.longhorn.io "$NODE" \
    --type=merge \
    -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}'

echo ""
echo "=== Fertig ==="
echo "Node '$NODE' ist wieder im Cluster und empfängt Workloads."
