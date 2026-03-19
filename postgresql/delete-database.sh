#!/usr/bin/env bash
set -euo pipefail

# Usage: ./delete-database.sh <db-name>
DB_NAME="${1:-}"
if [[ -z "$DB_NAME" ]]; then
  echo "Usage: $0 <db-name>"
  exit 1
fi

PG_NAMESPACE="postgresql"
DB_USER="$DB_NAME"
SECRET_NAME="postgresql-creds-${DB_NAME}"

echo "=== PostgreSQL Datenbank löschen ==="
echo "Datenbank : $DB_NAME"
echo "User      : $DB_USER"
echo ""
read -rp "Wirklich löschen? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Abgebrochen."
  exit 0
fi

# === 1. DATABASE CR ===
echo ""
echo "==> Database CR löschen..."
if kubectl get database "$DB_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  kubectl delete database "$DB_NAME" -n "$PG_NAMESPACE"
else
  echo "Database CR nicht gefunden – übersprungen."
fi

# === 2. MANAGED ROLE AUS CLUSTER ENTFERNEN ===
echo ""
echo "==> Managed Role aus CNPG Cluster entfernen..."
ROLES=$(kubectl get cluster postgresql -n "$PG_NAMESPACE" -o json \
  | jq --arg user "$DB_USER" '[.spec.managed.roles[]? | select(.name != $user)]')
kubectl patch cluster postgresql -n "$PG_NAMESPACE" --type=merge \
  -p "{\"spec\":{\"managed\":{\"roles\":$ROLES}}}"

# === 3. CREDENTIALS SECRET ===
echo ""
echo "==> Credentials-Secret löschen..."
if kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  kubectl delete secret "$SECRET_NAME" -n "$PG_NAMESPACE"
else
  echo "Secret nicht gefunden – übersprungen."
fi

# === 4. ALLE AUTHORIZATION POLICIES FÜR DIESE DB ===
echo ""
echo "==> AuthorizationPolicies löschen..."
kubectl get authorizationpolicy -n "$PG_NAMESPACE" \
  --no-headers -o custom-columns=NAME:.metadata.name \
  | grep "^postgresql-allow-${DB_NAME}-" \
  | xargs -r kubectl delete authorizationpolicy -n "$PG_NAMESPACE"

echo ""
echo "=== Fertig ==="
echo "Datenbank '$DB_NAME' und alle zugehörigen Ressourcen wurden gelöscht."
