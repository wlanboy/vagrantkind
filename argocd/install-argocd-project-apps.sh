#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Applying cluster config and project..."
kubectl apply -f "$ROOT_DIR/argocd-projects/cluster-gmk.yaml"
kubectl apply -f "$ROOT_DIR/argocd-projects/wlanboy-project.yaml"

echo "Applying namespaces..."
kubectl apply -f "$ROOT_DIR/argocd-namespaces/"

echo "Applying ArgoCD apps..."
kubectl apply -f "$ROOT_DIR/argocd-apps/"

echo "Done."
