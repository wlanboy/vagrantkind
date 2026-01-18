#!/bin/bash
set -euo pipefail

# Prüfen ob benötigte Tools vorhanden sind
for cmd in helm kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd ist nicht installiert"
        exit 1
    fi
done

echo "Füge Argo Helm Repository hinzu..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "Installiere ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
    -n argocd \
    --create-namespace \
    -f argocd-values-istio.yaml \
    --wait

echo "Warte auf ArgoCD Pods..."
kubectl -n argocd wait --for=condition=Ready --all pods --timeout=120s

echo "Erstelle ArgoCD Certificate..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-cert-secret
  namespace: istio-ingress
spec:
  secretName: argocd-cert-secret
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  commonName: argocd.tp.lan
  isCA: false
  usages:
    - server auth
    - client auth
  dnsNames:
    - argocd.tp.lan
    - argocd.gmk.lan
  issuerRef:
    name: local-ca-issuer
    kind: ClusterIssuer
EOF

echo "Erstelle Istio Gateway..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: istio-ingress
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: argocd-cert-secret
    hosts:
    - "argocd.tp.lan"
    - "argocd.gmk.lan"
EOF

echo "Erstelle VirtualService..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: argocd-vs
  namespace: argocd
spec:
  hosts:
  - "argocd.tp.lan"
  - "argocd.gmk.lan"
  exportTo:
  - "."
  - istio-ingress
  - istio-system
  gateways:
  - istio-ingress/argocd-gateway
  - mesh
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: argocd-server
        port:
          number: 80
EOF

echo ""
echo "ArgoCD Admin-Passwort:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "ArgoCD Installation abgeschlossen."
