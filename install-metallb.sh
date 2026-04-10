#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.sh
source "$SCRIPT_DIR/versions.sh"

# MetalLB installieren
echo "Installing MetalLB (version ${METALLB_VERSION})..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"

echo "Warte auf MetalLB..."
kubectl -n metallb-system rollout status deployment --timeout=120s
kubectl -n metallb-system rollout status daemonset --timeout=120s

kubectl apply -f metallb-pool-k3s.yaml
kubectl apply -f metallb-adv.yaml
echo "MetalLB konfiguriert."
