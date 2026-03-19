#!/usr/bin/env bash
set -euo pipefail

# Usage: ./revoke-namespace-access.sh <db-name> <target-namespace>
DB_NAME="${1:-}"
TARGET_NS="${2:-}"

if [[ -z "$DB_NAME" || -z "$TARGET_NS" ]]; then
  echo "Usage: $0 <db-name> <target-namespace>"
  exit 1
fi

PG_NAMESPACE="postgresql"
POLICY_NAME="postgresql-allow-${DB_NAME}-${TARGET_NS}"

echo "=== Namespace-Zugriff entziehen ==="
echo "Datenbank  : $DB_NAME"
echo "Namespace  : $TARGET_NS"

if kubectl get authorizationpolicy "$POLICY_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  kubectl delete authorizationpolicy "$POLICY_NAME" -n "$PG_NAMESPACE"
  echo ""
  echo "=== Fertig ==="
  echo "Namespace '$TARGET_NS' hat keinen Zugriff mehr auf '$DB_NAME'."
else
  echo ""
  echo "Policy '$POLICY_NAME' nicht gefunden – nichts zu tun."
fi
