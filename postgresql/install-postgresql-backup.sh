#!/usr/bin/env bash
set -euo pipefail

PG_NAMESPACE="postgresql"
SCHEDULE="${SCHEDULE:-0 3 * * *}"
RETAIN="${RETAIN:-5}"

echo "=== PostgreSQL Backup Setup ==="
echo "Schedule : $SCHEDULE"
echo "Retain   : $RETAIN Snapshots"

# === 1. VOLUMESNAPSHOTCLASS ===
echo ""
echo "==> VolumeSnapshotClass für Longhorn anlegen..."
kubectl apply -f - <<'YAML'
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: longhorn-snapshot
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "false"
driver: driver.longhorn.io
deletionPolicy: Delete
parameters:
  type: snap
YAML

# === 2. SCHEDULED BACKUP ===
echo ""
echo "==> ScheduledBackup anlegen..."
kubectl apply -f - <<YAML
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: postgresql-backup
  namespace: $PG_NAMESPACE
spec:
  schedule: "0 $SCHEDULE"
  backupOwnerReference: self
  method: volumeSnapshot
  cluster:
    name: postgresql
  immediate: true
YAML

echo ""
echo "=== Fertig ==="
echo "Schedule : $SCHEDULE"
echo "Retain   : $RETAIN Snapshots"
echo ""
echo "Longhorn sichert die Snapshots nightly auf NFS (gmk:/k8s-backups)."
echo "Manuelles Backup: kubectl cnpg backup postgresql -n $PG_NAMESPACE --method volumeSnapshot"
