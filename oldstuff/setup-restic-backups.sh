#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
NFS_SERVER="gmk"
NFS_PATH="/k8s-backups"
RESTIC_PASSWORD_FILE="/root/restic-password"
BACKUP_SCHEDULE="0 3 * * *"   # täglich um 03:00
RETENTION_DAYS=7
NAMESPACE="default"           # Namespace für CronJobs
# ===============

echo "=== Restic PVC Backup Setup ==="

# 1. Prüfen, ob Passwort existiert
if [ ! -f "$RESTIC_PASSWORD_FILE" ]; then
    echo "ERROR: Restic Passwortdatei fehlt: $RESTIC_PASSWORD_FILE"
    exit 1
fi

# 2. Alle PVCs finden
echo "-> Suche PVCs..."
PVC_LIST=$(kubectl get pvc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{";"}{.metadata.name}{"\n"}{end}')

if [ -z "$PVC_LIST" ]; then
    echo "Keine PVCs gefunden."
    exit 0
fi

echo "Gefundene PVCs:"
echo "$PVC_LIST"
echo

# 3. Für jedes PVC CronJob erstellen
echo "-> Erstelle CronJobs..."

while IFS=";" read -r NS PVC; do
    [ -z "$NS" ] && continue

    JOB_NAME="backup-${NS}-${PVC}"
    REPO_PATH="${NFS_PATH}/${NS}-${PVC}"

    echo "PVC: $PVC (Namespace: $NS)"
    echo "  -> Repository: ${REPO_PATH}"

    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${JOB_NAME}
  namespace: ${NAMESPACE}
spec:
  schedule: "${BACKUP_SCHEDULE}"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: restic-backup
            image: restic/restic:latest
            env:
            - name: RESTIC_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: restic-password
                  key: password
            command:
            - /bin/sh
            - -c
            - |
              echo "Starte Backup für PVC ${PVC}"
              restic -r /backup init || true
              restic -r /backup backup /data
              restic -r /backup forget --keep-within ${RETENTION_DAYS}d --prune
            volumeMounts:
            - name: data
              mountPath: /data
            - name: backup
              mountPath: /backup
          volumes:
          - name: data
            persistentVolumeClaim:
              claimName: ${PVC}
          - name: backup
            nfs:
              server: ${NFS_SERVER}
              path: ${REPO_PATH}
EOF

done <<< "$PVC_LIST"

echo
echo "=== Fertig ==="
echo "Alle PVCs werden nun täglich um 03:00 auf NFS gesichert."
echo "Backups liegen unter: ${NFS_SERVER}:${NFS_PATH}"
