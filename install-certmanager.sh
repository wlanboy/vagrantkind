#!/bin/bash
set -euo pipefail

CA_CERT="/local-ca/ca.pem"
CA_KEY="/local-ca/ca.key"

# Prüfen ob benötigte Tools vorhanden sind
for cmd in helm kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd ist nicht installiert"
        exit 1
    fi
done

# Prüfen ob CA-Dateien existieren
if [[ ! -f "$CA_CERT" ]]; then
    echo "Fehler: CA-Zertifikat nicht gefunden: $CA_CERT"
    exit 1
fi
if [[ ! -f "$CA_KEY" ]]; then
    echo "Fehler: CA-Key nicht gefunden: $CA_KEY"
    exit 1
fi

echo "Erstelle cert-manager Namespace..."
kubectl get ns cert-manager &>/dev/null || kubectl create namespace cert-manager

echo "Füge Jetstack Helm Repository hinzu..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo "Installiere cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --set crds.enabled=true \
    --wait

echo "Warte auf cert-manager Pods..."
kubectl -n cert-manager wait --for=condition=Ready --all pods --timeout=120s

echo "Erstelle CA Secret..."
kubectl create secret tls my-local-ca-secret \
    --namespace cert-manager \
    --cert="$CA_CERT" \
    --key="$CA_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Erstelle ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: local-ca-issuer
spec:
  ca:
    secretName: my-local-ca-secret
EOF

echo "Überprüfe den Status der cert-manager-Pods..."
kubectl get pods -n cert-manager -o wide

echo "Überprüfe die cert-manager-Installation..."
kubectl get clusterissuers

echo "Cert-Manager Installation abgeschlossen."