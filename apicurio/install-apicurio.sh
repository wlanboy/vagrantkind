#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

# Prüfen ob benötigte Tools vorhanden sind
for cmd in kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd ist nicht installiert"
        exit 1
    fi
done

echo "Erstelle Namespace und Basis-Ressourcen..."
kubectl apply -f "${MANIFESTS_DIR}/namespace.yaml"
kubectl apply -f "${MANIFESTS_DIR}/secret.yaml"

echo "Erstelle PersistentVolumeClaim für PostgreSQL..."
kubectl apply -f "${MANIFESTS_DIR}/postgres-pvc.yaml"

echo "Deploye PostgreSQL..."
kubectl apply -f "${MANIFESTS_DIR}/postgres-deployment.yaml"
kubectl apply -f "${MANIFESTS_DIR}/postgres-service.yaml"

echo "Warte bis PostgreSQL bereit ist..."
kubectl rollout status deployment/apicurio-db -n apicurio --timeout=120s

echo "Deploye Apicurio Registry..."
kubectl apply -f "${MANIFESTS_DIR}/registry-deployment.yaml"
kubectl apply -f "${MANIFESTS_DIR}/registry-service.yaml"

echo "Warte bis Apicurio Registry bereit ist..."
kubectl rollout status deployment/apicurio-registry -n apicurio --timeout=180s

echo "Erstelle Certificate..."
kubectl apply -f "${MANIFESTS_DIR}/certificate.yaml"

echo "Erstelle Istio Gateway..."
kubectl apply -f "${MANIFESTS_DIR}/gateway.yaml"

echo "Erstelle VirtualService..."
kubectl apply -f "${MANIFESTS_DIR}/virtualservice.yaml"

echo ""
echo "Apicurio Registry erfolgreich installiert."
echo ""
echo "Erreichbar unter:"
echo "  https://apicurio.tp.lan"
echo "  https://apicurio.gmk.lan"
