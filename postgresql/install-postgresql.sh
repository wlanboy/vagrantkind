#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="postgresql"

echo "=== CloudNativePG Installation ==="

# === 1. CNPG OPERATOR ===
echo ""
echo "==> Helm Repo hinzufügen..."
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

echo "==> CNPG Operator installieren..."
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --wait

# === 2. NAMESPACE & STORAGECLASS ===
echo ""
echo "==> Namespace erstellen..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Longhorn StorageClass für PostgreSQL anlegen..."
kubectl apply -f "$(dirname "$0")/storageclass.yaml"

# === 3. APP-SECRET ===
echo ""
echo "==> Secret für App-User prüfen..."
if ! kubectl get secret postgresql-app-secret -n "$NAMESPACE" &>/dev/null; then
  PG_PASSWORD=$(openssl rand -base64 16)
  kubectl create secret generic postgresql-app-secret \
    --namespace "$NAMESPACE" \
    --from-literal=username=app \
    --from-literal=password="$PG_PASSWORD"
  echo "Secret angelegt. Passwort: $PG_PASSWORD"
else
  echo "Secret existiert bereits – wird nicht überschrieben."
fi

# === 4. CLUSTER ===
echo ""
echo "==> PostgreSQL Cluster anlegen..."
kubectl apply -f "$(dirname "$0")/cluster.yaml"

echo ""
echo "==> Warte auf Cluster Ready..."
kubectl -n "$NAMESPACE" wait cluster/postgresql \
  --for=condition=Ready \
  --timeout=300s

echo ""
echo "=== Fertig ==="
echo "Namespace     : $NAMESPACE"
echo "Instances     : 3 (1 Primary + 2 Standby)"
echo "StorageClass  : longhorn-postgresql (1 Replica)"
echo "App-User      : app"
echo ""
echo "Primary Service : postgresql-rw.$NAMESPACE.svc.cluster.local:5432"
echo "Replica Service : postgresql-ro.$NAMESPACE.svc.cluster.local:5432"
echo ""
echo "Von CNPG automatisch angelegte Secrets im Namespace '$NAMESPACE':"
echo "  postgresql-superuser  – postgres-Superuser (für Admin-Operationen und Restore)"
echo "  postgresql-app-secret – app-User (Bootstrap-Datenbank)"
echo ""
echo "Istio: ./install-postgresql-istio.sh ausführen um Gateway und VirtualService anzulegen."
