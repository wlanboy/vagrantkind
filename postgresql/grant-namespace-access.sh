#!/usr/bin/env bash
set -euo pipefail

# Usage: ./grant-namespace-access.sh <db-name> <target-namespace>
DB_NAME="${1:-}"
TARGET_NS="${2:-}"

if [[ -z "$DB_NAME" || -z "$TARGET_NS" ]]; then
  echo "Usage: $0 <db-name> <target-namespace>"
  exit 1
fi

PG_NAMESPACE="postgresql"

echo "=== Namespace-Zugriff freischalten ==="
echo "Datenbank  : $DB_NAME"
echo "Namespace  : $TARGET_NS"

# Hinweis zur Isolation: Diese AuthorizationPolicy steuert TCP-Konnektivität
# auf Port 5432 zum gesamten PostgreSQL-Cluster – nicht zu einer spezifischen
# Datenbank. Die eigentliche Datenbank-Isolation erfolgt durch PostgreSQL-Credentials
# (Benutzer darf nur auf "seine" Datenbank zugreifen).
# Der Policy-Name enthält den DB-Namen zur Nachvollziehbarkeit (welcher Namespace
# für welche DB freigeschaltet wurde), hat aber keinen technischen Effekt auf
# die Filterung einzelner Datenbanken.
kubectl apply -f - <<YAML
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: "postgresql-allow-${DB_NAME}-${TARGET_NS}"
  namespace: $PG_NAMESPACE
spec:
  selector:
    matchLabels:
      cnpg.io/cluster: postgresql
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces:
        - "$TARGET_NS"
    to:
    - operation:
        ports:
        - "5432"
YAML

echo ""
echo "=== Fertig ==="
echo "Namespace '$TARGET_NS' darf auf Port 5432 des PostgreSQL-Clusters zugreifen."
echo "Datenbank-Isolation erfolgt via PostgreSQL-Credentials (User: $DB_NAME)."
