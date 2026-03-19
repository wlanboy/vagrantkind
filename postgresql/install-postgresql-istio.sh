#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="postgresql"

echo "=== PostgreSQL Istio Setup ==="

# === 1. SIDECAR INJECTION ===
echo ""
echo "==> Istio Sidecar-Injection aktivieren..."
kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite

# === 2. GATEWAY ===
echo ""
echo "==> Gateway (TCP/5432) anlegen..."
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: postgresql-gateway
  namespace: postgresql
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 5432
      name: tcp-postgresql
      protocol: TCP
    hosts:
    - "*"
YAML

# === 3. VIRTUALSERVICE ===
echo "==> VirtualService anlegen..."
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: postgresql-vs
  namespace: postgresql
spec:
  hosts:
  - "*"
  gateways:
  - postgresql/postgresql-gateway
  - mesh
  tcp:
  - match:
    - port: 5432
    route:
    - destination:
        host: postgresql-rw
        port:
          number: 5432
YAML

echo ""
echo "=== Fertig ==="
echo "Hinweis: Port 5432 muss am istio-ingressgateway Service offen sein."
