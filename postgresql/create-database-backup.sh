#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create-database-backup.sh <db-name> [schedule] [retain]
DB_NAME="${1:-}"
SCHEDULE="${2:-0 2 * * *}"
RETAIN="${3:-7}"

if [[ -z "$DB_NAME" ]]; then
  echo "Usage: $0 <db-name> [schedule] [retain]"
  echo "  schedule : cron-Ausdruck (default: '0 2 * * *')"
  echo "  retain   : Anzahl Backups (default: 7)"
  exit 1
fi

PG_NAMESPACE="postgresql"
NFS_SERVER="gmk"
NFS_PATH="/k8s-backups/postgresql"
SECRET_NAME="postgresql-creds-${DB_NAME}"

if ! kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" &>/dev/null; then
  echo "Fehler: Secret '$SECRET_NAME' nicht gefunden. Erst ./create-database.sh ausführen."
  exit 1
fi

DB_USER=$(kubectl get secret "$SECRET_NAME" -n "$PG_NAMESPACE" \
  -o jsonpath='{.data.username}' | base64 -d)

echo "=== PostgreSQL DB-Backup einrichten ==="
echo "Datenbank : $DB_NAME"
echo "Schedule  : $SCHEDULE"
echo "Retain    : $RETAIN Backups"

# === 1. NFS PV + PVC (einmalig, geteilt für alle DB-Backups) ===
echo ""
echo "==> NFS PersistentVolume anlegen..."
kubectl apply -f - <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgresql-backup-nfs
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: $NFS_SERVER
    path: $NFS_PATH
  mountOptions:
  - nfsvers=4.1
YAML

kubectl apply -f - <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-backup-nfs
  namespace: $PG_NAMESPACE
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  volumeName: postgresql-backup-nfs
  storageClassName: ""
YAML

# === 2. CRONJOB ===
echo ""
echo "==> CronJob anlegen..."
kubectl apply -f - <<YAML
apiVersion: batch/v1
kind: CronJob
metadata:
  name: "postgresql-backup-${DB_NAME}"
  namespace: $PG_NAMESPACE
spec:
  schedule: "$SCHEDULE"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: pg-dump
            image: postgres:16
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: "$SECRET_NAME"
                  key: password
            command:
            - /bin/sh
            - -c
            - |
              set -e
              TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
              DIR="/backups/$DB_NAME"
              FILE="\${DIR}/\${TIMESTAMP}.dump"
              mkdir -p "\$DIR"
              echo "Starte Backup: \$FILE"
              pg_dump \
                -h postgresql-rw.$PG_NAMESPACE.svc.cluster.local \
                -U $DB_USER \
                -Fc \
                $DB_NAME > "\$FILE"
              echo "Backup abgeschlossen."
              # Alte Backups aufräumen
              ls -t "\${DIR}"/*.dump | tail -n +$(( RETAIN + 1 )) | xargs -r rm -v
            volumeMounts:
            - name: backup
              mountPath: /backups
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: postgresql-backup-nfs
YAML

echo ""
echo "=== Fertig ==="
echo "Datenbank : $DB_NAME"
echo "Schedule  : $SCHEDULE"
echo "Retain    : $RETAIN Backups"
echo "Speicherort: ${NFS_SERVER}:${NFS_PATH}/${DB_NAME}/"
echo ""
echo "Manueller Backup-Lauf:"
echo "  kubectl create job -n $PG_NAMESPACE --from=cronjob/postgresql-backup-${DB_NAME} backup-${DB_NAME}-manual"
