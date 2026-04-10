#!/bin/bash
set -euo pipefail

METALLB_VERSION="0.15.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prüfen ob benötigte Tools vorhanden sind
for cmd in kind kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd ist nicht installiert"
        exit 1
    fi
done

# Prüfen ob Config-Datei existiert
if [[ ! -f "$SCRIPT_DIR/kind-local.yaml" ]]; then
    echo "Fehler: kind-local.yaml nicht gefunden"
    exit 1
fi

echo "Erstelle Kind Cluster..."
if kind get clusters 2>/dev/null | grep -q "^local$"; then
    echo "Kind Cluster 'local' existiert bereits, überspringe Erstellung."
else
    kind create cluster --config="$SCRIPT_DIR/kind-local.yaml"
fi

echo "Warte auf Cluster..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "Installing MetalLB (version ${METALLB_VERSION})..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"

echo "Warte auf MetalLB..."
kubectl -n metallb-system rollout status deployment --timeout=120s
kubectl -n metallb-system rollout status daemonset --timeout=120s

kubectl apply -f "$SCRIPT_DIR/metallb-pool.yaml"
kubectl apply -f "$SCRIPT_DIR/metallb-adv.yaml"
echo "MetalLB konfiguriert."

echo "Kind Cluster Installation abgeschlossen."

# Delete cluster
# kind delete clusters local
