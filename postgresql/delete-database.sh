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
  --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
  | grep "^postgresql-allow-${DB_NAME}-" \
  | xargs -r kubectl delete authorizationpolicy -n "$PG_NAMESPACE" \
  || echo "Keine AuthorizationPolicies gefunden oder Istio nicht installiert."

# === 5. BACKUP-CRONJOBS IN ALLEN NAMESPACES ===
echo ""
echo "==> Backup-CronJobs in allen Namespaces löschen..."
CRONJOB_NAME="postgresql-backup-${DB_NAME}"
while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue
  echo "  Lösche CronJob '$CRONJOB_NAME' in Namespace '$ns'..."
  kubectl delete cronjob "$CRONJOB_NAME" -n "$ns" --ignore-not-found
done < <(kubectl get cronjob --all-namespaces --no-headers \
  -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name 2>/dev/null \
  | awk -v name="$CRONJOB_NAME" '$2 == name {print $1}')

# === 6. CONNECTION-SECRETS IN ALLEN NAMESPACES ===
# create-connection-secret.sh legt in jedem Ziel-Namespace ein Secret
# 'postgresql-<db-name>' an – diese werden hier bereinigt.
echo ""
echo "==> Connection-Secrets in allen Namespaces löschen..."
SECRET_CONN="postgresql-${DB_NAME}"
while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue
  echo "  Lösche Secret '$SECRET_CONN' in Namespace '$ns'..."
  kubectl delete secret "$SECRET_CONN" -n "$ns" --ignore-not-found
done < <(kubectl get secret --all-namespaces --no-headers \
  -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name 2>/dev/null \
  | awk -v name="$SECRET_CONN" '$2 == name {print $1}')

# Hinweis: PVCs (postgresql-backup-nfs) und PVs (postgresql-backup-nfs-<namespace>)
# werden NICHT gelöscht, da sie pro Namespace gemeinsam von mehreren Datenbanken
# genutzt werden. Bei Bedarf manuell löschen:
#   kubectl delete pvc postgresql-backup-nfs -n <namespace>
#   kubectl delete pv postgresql-backup-nfs-<namespace>

echo ""
echo "=== Fertig ==="
echo "Datenbank '$DB_NAME' und alle zugehörigen Ressourcen wurden gelöscht."
