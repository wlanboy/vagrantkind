#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  read -rsp "GitHub Personal Access Token: " GITHUB_TOKEN
  echo
fi
kubectl delete secret github-token -n argocd --ignore-not-found
kubectl create secret generic github-token -n argocd --from-literal=token="$GITHUB_TOKEN"

echo "Hole ArgoCD Token aus Cluster..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
kubectl port-forward -n argocd svc/argocd-server 8080:80 &>/dev/null &
PF_PID=$!
sleep 3
ARGOCD_TOKEN=$(curl -s http://localhost:8080/api/v1/session \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"${ARGOCD_PASSWORD}\"}" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
kill "$PF_PID"

kubectl delete secret argocd-sync-token -n argocd --ignore-not-found
kubectl create secret generic argocd-sync-token -n argocd --from-literal=token="$ARGOCD_TOKEN"

echo "Applying ArgoCD workflow events..."
kubectl apply -f "$ROOT_DIR/argocd-events/"

echo "Done."
