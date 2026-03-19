#!/usr/bin/env bash
set -euo pipefail

PG_NAMESPACE="postgresql"
# 5-Felder Cron (Min Std Tag Mon Woche) – wird intern zu 6 Feldern (Sek vorne) erweitert,
# da CNPG ScheduledBackup ein sekundenbasiertes Cron-Format erwartet.
SCHEDULE="${SCHEDULE:-0 3 * * *}"
CRON_SCHEDULE="0 ${SCHEDULE}"

# Hinweis: CNPG ScheduledBackup unterstützt keine retentionPolicy für volumeSnapshot.
# Die Snapshot-Retention wird über die Longhorn-Backup-Konfiguration (gmk:/k8s-backups) gesteuert.
RETAIN="${RETAIN:-5}"

echo "=== PostgreSQL Backup Setup ==="
echo "Schedule      : $SCHEDULE (→ CNPG: $CRON_SCHEDULE)"
echo "Retain        : $RETAIN Snapshots (via Longhorn-Retention konfigurieren)"

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
  schedule: "$CRON_SCHEDULE"
  backupOwnerReference: self
  method: volumeSnapshot
  cluster:
    name: postgresql
  immediate: true
YAML

echo ""
echo "=== Fertig ==="
echo "Schedule : $CRON_SCHEDULE"
echo "Retain   : $RETAIN Snapshots (Konfiguration in Longhorn erforderlich)"
echo ""
echo "Longhorn sichert die Snapshots nightly auf NFS (gmk:/k8s-backups)."
echo "Manuelles Backup: kubectl cnpg backup postgresql -n $PG_NAMESPACE --method volumeSnapshot"
