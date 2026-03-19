#!/usr/bin/env bash
set -euo pipefail

PG_NAMESPACE="postgresql"

echo "=== PostgreSQL Restore ==="

# === 1. VERFÜGBARE BACKUPS ANZEIGEN ===
echo ""
echo "Verfügbare Backups:"
echo ""

mapfile -t BACKUP_NAMES < <(kubectl get backup -n "$PG_NAMESPACE" \
  -o jsonpath='{range .items[?(@.status.phase=="completed")]}{.metadata.name}{"\n"}{end}')

if [[ ${#BACKUP_NAMES[@]} -eq 0 ]]; then
  echo "Keine abgeschlossenen Backups gefunden."
  exit 1
fi

for i in "${!BACKUP_NAMES[@]}"; do
  NAME="${BACKUP_NAMES[$i]}"
  STARTED=$(kubectl get backup "$NAME" -n "$PG_NAMESPACE" \
    -o jsonpath='{.status.startedAt}')
  STOPPED=$(kubectl get backup "$NAME" -n "$PG_NAMESPACE" \
    -o jsonpath='{.status.stoppedAt}')
  METHOD=$(kubectl get backup "$NAME" -n "$PG_NAMESPACE" \
    -o jsonpath='{.spec.method}')
  printf "  [%d] %s\n      Gestartet : %s\n      Beendet   : %s\n      Methode   : %s\n\n" \
    "$((i+1))" "$NAME" "$STARTED" "$STOPPED" "$METHOD"
done

# === 2. AUSWAHL ===
read -rp "Backup auswählen [1-${#BACKUP_NAMES[@]}]: " SELECTION
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || \
   (( SELECTION < 1 || SELECTION > ${#BACKUP_NAMES[@]} )); then
  echo "Ungültige Auswahl."
  exit 1
fi

SELECTED_BACKUP="${BACKUP_NAMES[$((SELECTION-1))]}"
echo ""
echo "Gewähltes Backup: $SELECTED_BACKUP"

# === 3. BESTÄTIGUNG ===
echo ""
echo "ACHTUNG: Der bestehende Cluster wird gelöscht und aus dem Backup wiederhergestellt."
echo "Alle nicht gesicherten Daten gehen verloren."
echo ""
read -rp "Wirklich wiederherstellen? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Abgebrochen."
  exit 0
fi

# === 4. CLUSTER LÖSCHEN ===
echo ""
echo "==> Bestehenden Cluster löschen..."
kubectl delete cluster postgresql -n "$PG_NAMESPACE" --ignore-not-found

echo "==> Warte bis alle Pods beendet sind..."
kubectl wait pod \
  --selector cnpg.io/cluster=postgresql \
  --for=delete \
  --namespace "$PG_NAMESPACE" \
  --timeout=120s 2>/dev/null || true

# === 5. CLUSTER AUS BACKUP WIEDERHERSTELLEN ===
echo ""
echo "==> Cluster aus Backup '$SELECTED_BACKUP' wiederherstellen..."
kubectl apply -f - <<YAML
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql
  namespace: $PG_NAMESPACE
spec:
  instances: 3

  storage:
    storageClass: longhorn-postgresql
    size: 10Gi

  walStorage:
    storageClass: longhorn-postgresql
    size: 5Gi

  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"

  backup:
    volumeSnapshot:
      className: longhorn-snapshot

  bootstrap:
    recovery:
      backup:
        name: "$SELECTED_BACKUP"
YAML

# === 6. WARTEN ===
echo ""
echo "==> Warte auf Cluster Ready..."
kubectl -n "$PG_NAMESPACE" wait cluster/postgresql \
  --for=condition=Ready \
  --timeout=300s

echo ""
echo "=== Fertig ==="
echo "Cluster wiederhergestellt aus Backup '$SELECTED_BACKUP'."
