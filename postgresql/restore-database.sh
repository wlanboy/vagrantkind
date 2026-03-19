#!/usr/bin/env bash
set -euo pipefail

# Usage: ./restore-database.sh <db-name> [namespace]
DB_NAME="${1:-}"
TARGET_NS="${2:-postgresql}"
if [[ -z "$DB_NAME" ]]; then
  echo "Usage: $0 <db-name> [namespace]"
  echo "  namespace : Namespace des CronJob/PVC (default: postgresql)"
  exit 1
fi

PG_NAMESPACE="postgresql"
SECRET_NAME="postgresql-creds-${DB_NAME}"
SU_SECRET_NAME="postgresql-superuser"
LISTER_POD="postgresql-restore-lister"
PVC_NAME="postgresql-backup-nfs"
JOB_SECRET=""

# Trap: temporäre Ressourcen bei jedem Exit aufräumen (Fehler, Abbruch, Erfolg)
cleanup() {
  kubectl delete pod "$LISTER_POD" -n "$TARGET_NS" --ignore-not-found &>/dev/null || true
  if [[ -n "$JOB_SECRET" ]]; then
    kubectl delete secret "$JOB_SECRET" -n "$TARGET_NS" --ignore-not-found &>/dev/null || true
  fi
}
trap cleanup EXIT

if ! kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  echo "Fehler: Secret '$SECRET_NAME' nicht gefunden."
  exit 1
fi

# CNPG legt den Superuser-Secret automatisch an (postgresql-superuser)
if ! kubectl get secret "$SU_SECRET_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  echo "Fehler: Superuser-Secret '$SU_SECRET_NAME' nicht gefunden."
  echo "Hinweis: CNPG legt dieses Secret automatisch beim Cluster-Start an."
  exit 1
fi

DB_USER=$(kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" \
  -o jsonpath='{.data.username}' | base64 -d)
DB_PASSWORD=$(kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" \
  -o jsonpath='{.data.password}' | base64 -d)
SU_PASSWORD=$(kubectl get secret "$SU_SECRET_NAME" -n "$PG_NAMESPACE" \
  -o jsonpath='{.data.password}' | base64 -d)

echo "=== PostgreSQL Datenbank-Restore ==="
echo "Datenbank : $DB_NAME"

# === 1. VERFÜGBARE DUMPS AUFLISTEN ===
echo ""
echo "==> Verfügbare Backups werden geladen..."

kubectl run "$LISTER_POD" \
  --image=postgres:16 \
  --namespace="$TARGET_NS" \
  --restart=Never \
  --overrides="{
    \"spec\": {
      \"volumes\": [{\"name\":\"backup\",\"persistentVolumeClaim\":{\"claimName\":\"$PVC_NAME\"}}],
      \"containers\": [{
        \"name\": \"lister\",
        \"image\": \"postgres:16\",
        \"command\": [\"sleep\",\"60\"],
        \"volumeMounts\": [{\"name\":\"backup\",\"mountPath\":\"/backups\"}]
      }]
    }
  }" &>/dev/null

kubectl wait pod "$LISTER_POD" \
  --for=condition=Ready \
  --namespace="$TARGET_NS" \
  --timeout=60s &>/dev/null

mapfile -t DUMPS < <(kubectl exec "$LISTER_POD" -n "$TARGET_NS" -- \
  ls -t "/backups/${DB_NAME}/" 2>/dev/null | grep '\.dump$' || true)

kubectl delete pod "$LISTER_POD" -n "$TARGET_NS" --ignore-not-found &>/dev/null || true

if [[ ${#DUMPS[@]} -eq 0 ]]; then
  echo "Keine Backups gefunden für Datenbank '$DB_NAME'."
  exit 1
fi

echo ""
echo "Verfügbare Backups:"
echo ""
for i in "${!DUMPS[@]}"; do
  printf "  [%d] %s\n" "$((i+1))" "${DUMPS[$i]}"
done

# === 2. AUSWAHL ===
echo ""
read -rp "Backup auswählen [1-${#DUMPS[@]}]: " SELECTION
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || \
   (( SELECTION < 1 || SELECTION > ${#DUMPS[@]} )); then
  echo "Ungültige Auswahl."
  exit 1
fi

SELECTED_DUMP="${DUMPS[$((SELECTION-1))]}"
echo ""
echo "Gewähltes Backup : $SELECTED_DUMP"
echo ""
echo "ACHTUNG: Die Datenbank '$DB_NAME' wird überschrieben."
read -rp "Wirklich wiederherstellen? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Abgebrochen."
  exit 0
fi

# === 3. JOB-SECRET MIT CREDENTIALS ANLEGEN ===
# Passwörter nie im Klartext im Job-Manifest – stattdessen ein kurzlebiges
# Secret, das der Job via secretKeyRef referenziert.
echo ""
echo "==> Job-Credentials vorbereiten..."
JOB_SECRET="postgresql-restore-creds-$(date +%s)"
kubectl create secret generic "$JOB_SECRET" -n "$TARGET_NS" \
  --from-literal=su-password="$SU_PASSWORD" \
  --from-literal=app-password="$DB_PASSWORD"

# Passwörter aus Shell-Variablen entfernen
unset SU_PASSWORD DB_PASSWORD

# === 4. RESTORE JOB ===
echo ""
echo "==> Restore wird gestartet..."
JOB_NAME="postgresql-restore-${DB_NAME}-$(date +%s)"

kubectl apply -f - <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: "$JOB_NAME"
  namespace: $TARGET_NS
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pg-restore
        image: postgres:16
        env:
        - name: PGPASSWORD_SUPER
          valueFrom:
            secretKeyRef:
              name: "$JOB_SECRET"
              key: su-password
        - name: PGPASSWORD_APP
          valueFrom:
            secretKeyRef:
              name: "$JOB_SECRET"
              key: app-password
        command:
        - /bin/sh
        - -c
        - |
          set -e
          echo "Trenne bestehende Verbindungen..."
          PGPASSWORD="\${PGPASSWORD_SUPER}" psql \
            -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local -U postgres \
            -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"
          echo "Datenbank neu erstellen..."
          PGPASSWORD="\${PGPASSWORD_SUPER}" psql \
            -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local -U postgres \
            -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"
          PGPASSWORD="\${PGPASSWORD_SUPER}" psql \
            -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local -U postgres \
            -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
          echo "Restore läuft..."
          PGPASSWORD="\${PGPASSWORD_APP}" pg_restore \
            -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local \
            -U $DB_USER \
            -d $DB_NAME \
            --no-owner \
            --role=$DB_USER \
            /backups/$DB_NAME/$SELECTED_DUMP
          echo "Restore abgeschlossen."
        volumeMounts:
        - name: backup
          mountPath: /backups
      volumes:
      - name: backup
        persistentVolumeClaim:
          claimName: $PVC_NAME
YAML

# === 5. AUF JOB WARTEN (Complete oder Failed) ===
echo "==> Warte auf Restore-Job..."
if ! kubectl wait job/"$JOB_NAME" \
    --for=condition=Complete \
    --namespace="$TARGET_NS" \
    --timeout=300s 2>/dev/null; then
  FAILED=$(kubectl get job "$JOB_NAME" -n "$TARGET_NS" \
    -o jsonpath='{.status.failed}' 2>/dev/null || echo "0")
  echo ""
  if [[ "${FAILED:-0}" -gt 0 ]]; then
    echo "Fehler: Restore-Job ist fehlgeschlagen. Logs:"
  else
    echo "Fehler: Timeout beim Warten auf Restore-Job. Logs:"
  fi
  kubectl logs -n "$TARGET_NS" -l "job-name=$JOB_NAME" --tail=50 || true
  exit 1
fi

echo ""
echo "=== Fertig ==="
echo "Datenbank '$DB_NAME' wurde aus '$SELECTED_DUMP' wiederhergestellt."
