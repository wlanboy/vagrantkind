#!/usr/bin/env bash
set -euo pipefail

# Usage: ./restore-database.sh <db-name>
DB_NAME="${1:-}"
if [[ -z "$DB_NAME" ]]; then
  echo "Usage: $0 <db-name>"
  exit 1
fi

PG_NAMESPACE="postgresql"
SECRET_NAME="postgresql-creds-${DB_NAME}"
LISTER_POD="postgresql-restore-lister"

if ! kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  echo "Fehler: Secret '$SECRET_NAME' nicht gefunden."
  exit 1
fi

DB_USER=$(kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" \
  -o jsonpath='{.data.username}' | base64 -d)
DB_PASSWORD=$(kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" \
  -o jsonpath='{.data.password}' | base64 -d)

echo "=== PostgreSQL Datenbank-Restore ==="
echo "Datenbank : $DB_NAME"

# === 1. VERFÜGBARE DUMPS AUFLISTEN ===
echo ""
echo "==> Verfügbare Backups werden geladen..."

kubectl run "$LISTER_POD" \
  --image=postgres:16 \
  --namespace="$PG_NAMESPACE" \
  --restart=Never \
  --overrides='{
    "spec": {
      "volumes": [{"name":"backup","persistentVolumeClaim":{"claimName":"postgresql-backup-nfs"}}],
      "containers": [{
        "name": "lister",
        "image": "postgres:16",
        "command": ["sleep","60"],
        "volumeMounts": [{"name":"backup","mountPath":"/backups"}]
      }]
    }
  }' &>/dev/null

kubectl wait pod "$LISTER_POD" \
  --for=condition=Ready \
  --namespace="$PG_NAMESPACE" \
  --timeout=60s &>/dev/null

mapfile -t DUMPS < <(kubectl exec "$LISTER_POD" -n "$PG_NAMESPACE" -- \
  ls -t "/backups/${DB_NAME}/" 2>/dev/null | grep '\.dump$' || true)

kubectl delete pod "$LISTER_POD" -n "$PG_NAMESPACE" &>/dev/null

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

# === 3. RESTORE JOB ===
echo ""
echo "==> Restore wird gestartet..."
JOB_NAME="postgresql-restore-${DB_NAME}-$(date +%s)"

kubectl apply -f - <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: "$JOB_NAME"
  namespace: $PG_NAMESPACE
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pg-restore
        image: postgres:16
        env:
        - name: PGPASSWORD
          value: "$DB_PASSWORD"
        command:
        - /bin/sh
        - -c
        - |
          set -e
          echo "Trenne bestehende Verbindungen..."
          psql -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local -U postgres \
            -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"
          echo "Datenbank neu erstellen..."
          psql -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local -U postgres \
            -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"
          psql -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local -U postgres \
            -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
          echo "Restore läuft..."
          pg_restore \
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
          claimName: postgresql-backup-nfs
YAML

echo "==> Warte auf Restore-Job..."
kubectl wait job/"$JOB_NAME" \
  --for=condition=Complete \
  --namespace="$PG_NAMESPACE" \
  --timeout=300s

echo ""
echo "=== Fertig ==="
echo "Datenbank '$DB_NAME' wurde aus '$SELECTED_DUMP' wiederhergestellt."
