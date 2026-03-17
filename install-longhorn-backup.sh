#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
NFS_SERVER="gmk"
NFS_PATH="/k8s-backups"
NAMESPACE="longhorn-system"
SCHEDULE="0 3 * * *"
RETAIN=3

echo "=== Longhorn NFS Backup Target Setup ==="

# --- Configure NFS backup target via Longhorn Setting ---
echo "-> Setting backup target: nfs://${NFS_SERVER}:${NFS_PATH}"
cat <<EOF | kubectl apply -f -
apiVersion: longhorn.io/v1beta2
kind: Setting
metadata:
  name: backup-target
  namespace: ${NAMESPACE}
value: "nfs://${NFS_SERVER}:${NFS_PATH}"
EOF

# --- Standard-Job-Gruppe für alle NEUEN Volumes setzen ---
echo "-> Setting default recurring job group for new volumes..."
cat <<EOF | kubectl apply -f -
apiVersion: longhorn.io/v1beta2
kind: Setting
metadata:
  name: recurring-job-default-group
  namespace: ${NAMESPACE}
value: "default"
EOF

# --- RecurringJob: nightly backup for all volumes in 'default' group ---
echo "-> Applying RecurringJob 'nightly-backup'..."
cat <<EOF | kubectl apply -f -
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: nightly-backup
  namespace: ${NAMESPACE}
spec:
  cron: "${SCHEDULE}"
  task: "backup"
  retain: ${RETAIN}
  concurrency: 1
  groups:
    - default
EOF

echo
echo "=== Fertig ==="
echo "Backup Target : nfs://${NFS_SERVER}:${NFS_PATH}"
echo "Schedule      : ${SCHEDULE}"
echo "Retain        : ${RETAIN} Backups"
