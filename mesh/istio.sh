#!/bin/bash

CLUSTER_NAME="istio"
ISTIO_VERSION="1.26.2" #https://github.com/istio/istio/releases
ISTIO_HELM_REPO_NAME="istio"
ISTIO_HELM_REPO_URL="https://istio-release.storage.googleapis.com/charts"

echo "Füge das Istio Helm Repository hinzu und aktualisiere es..."
helm repo add "${ISTIO_HELM_REPO_NAME}" "${ISTIO_HELM_REPO_URL}"
helm repo update
echo "   Istio Helm Repository hinzugefügt und aktualisiert."

echo "Erstelle den 'istio-system' Namespace, falls er noch nicht existiert..."
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
echo "   Namespace 'istio-system' erstellt (oder existiert bereits)."

echo "Installiere 'istio-base' (CRDs und grundlegende Komponenten) Version ${ISTIO_VERSION}..."
helm install istio-base ${ISTIO_HELM_REPO_NAME}/base --version "${ISTIO_VERSION}" \
  --namespace istio-system \
  --wait
echo "   'istio-base' erfolgreich installiert."

echo "Installiere 'istiod' (Istio Control Plane) Version ${ISTIO_VERSION}..."
helm install istiod ${ISTIO_HELM_REPO_NAME}/istiod --version "${ISTIO_VERSION}" \
  --namespace istio-system \
  --wait
echo "   'istiod' erfolgreich installiert."

echo "Installiere 'istio-ingressgateway' (istio/gateway Chart) Version ${ISTIO_VERSION}..."
helm install istio-ingressgateway ${ISTIO_HELM_REPO_NAME}/gateway --version "${ISTIO_VERSION}" \
  --namespace istio-system \
  --wait
echo "   'istio-ingressgateway' erfolgreich installiert."

echo "Installiere 'istio-egressgateway' (istio/gateway Chart) Version ${ISTIO_VERSION}..."
helm install istio-egressgateway ${ISTIO_HELM_REPO_NAME}/gateway --version "${ISTIO_VERSION}" \
  --namespace istio-system \
  --set gatewayType=egress \
  --wait
echo "   'istio-eressgateway' erfolgreich installiert."

echo "Überprüfe den Status der Istio-Pods..."
kubectl get pods -n istio-system -o wide

echo ""
echo "--- Istio-Installation abgeschlossen! ---"
echo ""
echo "Du kannst jetzt die Istio-Installation überprüfen:"
echo "  - Überprüfe Pods: kubectl get pods -n istio-system"
echo "  - Überprüfe Services: kubectl get svc -n istio-system"
echo "  - Prüfe die Istio-CRDs: kubectl get crd | grep 'istio.io'"
echo ""
echo "Um einen Service durch das Istio Ingress Gateway freizulegen, musst du einen Gateway- und VirtualService definieren."
echo "Beispiel für das Abrufen der externen IP des Ingress Gateways (nachdem MetalLB eine IP zugewiesen hat):"
echo '  export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")'
echo '  export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath="{.spec.ports[?(@.name=="http2")].port}")'
echo '  echo "Istio Ingress Gateway IP: ${INGRESS_HOST}:${INGRESS_PORT}"'
echo ""
echo "Hinweis: Die externe IP des istio-ingressgateway-Services wird von MetalLB zugewiesen, sobald sie verfügbar ist."
echo "Dies kann einen Moment dauern, bis MetalLB die IP annonciert hat."
echo ""
