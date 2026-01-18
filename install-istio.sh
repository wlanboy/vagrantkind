#!/bin/bash
set -euo pipefail

# Prüfen ob benötigte Tools vorhanden sind
for cmd in helm kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd ist nicht installiert"
        exit 1
    fi
done

echo "Adding Istio Helm repository and updating..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
echo "Istio Helm repository added and updated."

echo "Creating 'istio-system' namespace if it doesn't exist..."
kubectl get ns istio-system &>/dev/null || kubectl create namespace istio-system
echo "'istio-system' namespace ensured."

echo "Installing Istio Base components into 'istio-system'..."
helm install istio-base istio/base -n istio-system --wait
echo "Istio Base installed."

echo "Installing Istiod (Istio Control Plane) into 'istio-system'..."
helm install istiod istio/istiod -n istio-system --wait
echo "Istiod installed and ready."

echo "Creating 'istio-ingress' namespace if it doesn't exist..."
kubectl get ns istio-ingress &>/dev/null || kubectl create namespace istio-ingress
echo "'istio-ingress' namespace ensured."

echo "Installing Istio Ingress Gateway into 'istio-ingress'..."
helm install istio-ingressgateway istio/gateway -n istio-ingress --wait
echo "Istio Ingress Gateway installed."

# --- Demo Service Deployment ---
echo "Deploying demo service..."
echo "Creating 'demo' namespace if it doesn't exist..."
kubectl get ns demo &>/dev/null || kubectl create namespace demo
echo "'demo' namespace ensured."

echo "Enabling Istio injection for the 'demo' namespace..."
kubectl label namespace demo istio-injection=enabled --overwrite
echo "Istio injection enabled for 'demo' namespace."

echo "Applying 'echo-service-istio.yaml' to deploy the demo service..."
kubectl apply -f echo-service-istio.yaml
echo "Demo service deployment initiated."

echo "Warte auf Demo-Service Pods..."
kubectl -n demo wait --for=condition=Ready --all pods --timeout=120s

echo "Istio Installation abgeschlossen."

# Manuelle Tests:
# curl -I -H "Host: demo.tp.lan" http://172.18.100.10/
# curl -I -H "Host: demo.tp.lan" http://192.168.178.200/
# curl -I -H "Host: demo.kube.lan" http://172.18.0.2:32024/
