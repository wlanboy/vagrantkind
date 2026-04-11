#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/versions.sh"

echo "Installing MetalLB (version ${METALLB_VERSION}) for WSL..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"

echo "Warte auf MetalLB Pods..."
kubectl -n metallb-system wait --for=condition=Ready --all pods --timeout=120s

kubectl apply -f "$SCRIPT_DIR/wsl-metallb-pool.yaml"
kubectl apply -f "$SCRIPT_DIR/wsl-metallb-adv.yaml"
echo "MetalLB konfiguriert."
