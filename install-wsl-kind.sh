#!/bin/bash
set -euo pipefail

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

echo "Kind Cluster Installation abgeschlossen."

# Delete cluster
# kind delete clusters local
