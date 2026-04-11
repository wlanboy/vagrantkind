#!/bin/bash
set -euo pipefail

# Prüfen ob als root ausgeführt wird (sollte nicht)
if [[ $EUID -eq 0 ]]; then
    echo "Bitte nicht als root ausführen"
    exit 1
fi

# Prüfen ob kubectl verfügbar ist
if ! command -v kubectl &>/dev/null; then
    echo "Fehler: kubectl nicht gefunden. K3s ist möglicherweise nicht installiert."
    exit 1
fi

# Prüfen ob K3s-Cluster erreichbar ist
if ! kubectl get nodes &>/dev/null; then
    echo "Fehler: K3s-Cluster nicht erreichbar. Kubeconfig prüfen."
    exit 1
fi

echo "=== K3s Automated Upgrade Controller ==="
echo ""

# 1. system-upgrade-controller installieren (CRDs + Controller)
echo "Installiere system-upgrade-controller..."
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/crd.yaml
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml

# Warten bis der Controller bereit ist
echo "Warte auf system-upgrade-controller..."
kubectl -n system-upgrade rollout status deployment/system-upgrade-controller --timeout=120s

echo ""

# 2. Upgrade-Plan für den Server-Node (Single-Node reicht ein Plan)
echo "Erstelle Upgrade-Plan für K3s (Stable Channel)..."
kubectl apply -f - <<'EOF'
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: k3s-server
  namespace: system-upgrade
  labels:
    k3s-upgrade: server
spec:
  concurrency: 1
  cordon: true
  nodeSelector:
    matchExpressions:
      - key: node-role.kubernetes.io/control-plane
        operator: In
        values: ["true"]
  serviceAccountName: system-upgrade
  upgrade:
    image: rancher/k3s-upgrade
  channel: https://update.k3s.io/v1-release/channels/stable
EOF

echo ""
echo "=== Upgrade-Plan aktiv ==="
echo ""
echo "Der system-upgrade-controller prüft nun regelmäßig auf neue K3s-Versionen"
echo "im Stable Channel und führt Upgrades automatisch durch."
echo ""
echo "Status prüfen:"
echo "  kubectl -n system-upgrade get plans -o wide"
echo "  kubectl -n system-upgrade get jobs"
echo ""
echo "Upgrade-Jobs live beobachten:"
echo "  kubectl -n system-upgrade get jobs -w"
