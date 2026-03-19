#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create-connection-secret.sh <db-name> <target-namespace>
DB_NAME="${1:-}"
TARGET_NS="${2:-}"

if [[ -z "$DB_NAME" || -z "$TARGET_NS" ]]; then
  echo "Usage: $0 <db-name> <target-namespace>"
  exit 1
fi

PG_NAMESPACE="postgresql"
SECRET_NAME="postgresql-creds-${DB_NAME}"

echo "=== Connection-Secret anlegen ==="
echo "Datenbank  : $DB_NAME"
echo "Namespace  : $TARGET_NS"

# Credentials aus dem PG-Namespace lesen
DB_USER=$(kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
DB_PASSWORD=$(kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
DB_HOST="postgresql-rw.${PG_NAMESPACE}.svc.cluster.local"

echo ""
echo "==> Secret im Namespace '$TARGET_NS' anlegen..."
kubectl create secret generic "postgresql-${DB_NAME}" \
  --namespace "$TARGET_NS" \
  --from-literal=host="$DB_HOST" \
  --from-literal=port="5432" \
  --from-literal=database="$DB_NAME" \
  --from-literal=username="$DB_USER" \
  --from-literal=password="$DB_PASSWORD" \
  --from-literal=url="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Fertig ==="
echo "Secret 'postgresql-${DB_NAME}' in Namespace '$TARGET_NS' angelegt."
