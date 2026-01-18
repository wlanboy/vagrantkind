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
kind create cluster --config="$SCRIPT_DIR/kind-local.yaml"

echo "Warte auf Cluster..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "Installing MetalLB (version ${METALLB_VERSION})..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"

echo "Warte auf MetalLB Pods..."
kubectl -n metallb-system wait --for=condition=Ready --all pods --timeout=120s

kubectl apply -f "$SCRIPT_DIR/wsl-metallb-pool.yaml"
kubectl apply -f "$SCRIPT_DIR/wsl-metallb-adv.yaml"
echo "MetalLB konfiguriert."

echo "Kind Cluster Installation abgeschlossen."

# Delete cluster
# kind delete clusters local
