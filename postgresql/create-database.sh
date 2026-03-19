#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create-database.sh <db-name> [connection-limit]
DB_NAME="${1:-}"
CONN_LIMIT="${2:--1}"   # -1 = unbegrenzt

if [[ -z "$DB_NAME" ]]; then
  echo "Usage: $0 <db-name> [connection-limit]"
  exit 1
fi

PG_NAMESPACE="postgresql"
DB_USER="$DB_NAME"
SECRET_NAME="postgresql-creds-${DB_NAME}"

echo "=== PostgreSQL Datenbank anlegen ==="
echo "Datenbank         : $DB_NAME"
echo "User              : $DB_USER"
echo "Connection Limit  : $CONN_LIMIT"

# === 1. CREDENTIALS SECRET IM PG-NAMESPACE ===
echo ""
echo "==> Credentials-Secret prüfen..."
if ! kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  DB_PASSWORD=$(openssl rand -base64 16)
  kubectl create secret generic "$SECRET_NAME" \
    --namespace "$PG_NAMESPACE" \
    --from-literal=username="$DB_USER" \
    --from-literal=password="$DB_PASSWORD"
  echo "Secret angelegt."
else
  echo "Secret existiert bereits – wird nicht überschrieben."
fi

# === 2. MANAGED ROLE VIA CNPG CLUSTER ===
echo ""
echo "==> Managed Role im CNPG Cluster registrieren..."
kubectl apply -f - <<YAML
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql
  namespace: $PG_NAMESPACE
spec:
  managed:
    roles:
    - name: "$DB_USER"
      login: true
      connectionLimit: $CONN_LIMIT
      passwordSecret:
        name: "$SECRET_NAME"
YAML

# === 3. DATABASE CR ===
echo ""
echo "==> Database CR anlegen..."
kubectl apply -f - <<YAML
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: "$DB_NAME"
  namespace: $PG_NAMESPACE
spec:
  name: "$DB_NAME"
  owner: "$DB_USER"
  cluster:
    name: postgresql
YAML

echo ""
echo "=== Fertig ==="
echo "Datenbank : $DB_NAME"
echo "User      : $DB_USER"
echo "Secret    : $SECRET_NAME (Namespace: $PG_NAMESPACE)"
echo ""
echo "Nächste Schritte:"
echo "  ./grant-namespace-access.sh $DB_NAME <namespace>"
echo "  ./create-connection-secret.sh $DB_NAME <namespace>"
