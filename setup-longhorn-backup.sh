#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="longhorn-system"
SCHEDULE="0 3 * * *"
RETAIN=3

echo "=== Longhorn Recurring Backup Setup (Idempotent) ==="

# 1. Prüfen, ob RecurringJob existiert
echo "-> Prüfe, ob RecurringJob 'nightly-backup' existiert..."

if kubectl -n ${NAMESPACE} get recurringjob nightly-backup >/dev/null 2>&1; then
    echo "RecurringJob 'nightly-backup' existiert bereits. Überspringe Erstellung."
else
    echo "RecurringJob existiert nicht. Erstelle ihn jetzt..."

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
EOF

    echo "RecurringJob 'nightly-backup' wurde erstellt."
fi

echo

# 2. Alle Volumes holen
echo "-> Hole alle Longhorn Volumes..."
VOLUMES=$(kubectl get volumes.longhorn.io -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}')

if [ -z "$VOLUMES" ]; then
    echo "Keine Volumes gefunden."
    exit 0
fi

echo "Gefundene Volumes:"
echo "$VOLUMES"
echo

# 3. RecurringJob jedem Volume zuweisen (idempotent)
echo "-> Weise RecurringJob jedem Volume zu..."

for VOL in $VOLUMES; do
    echo "Volume: $VOL"

    CURRENT=$(kubectl -n ${NAMESPACE} get volume ${VOL} -o jsonpath='{.spec.recurringJobSelector}' || echo "")

    if echo "$CURRENT" | grep -q '"nightly-backup"'; then
        echo "  -> Job bereits vorhanden, überspringe."
        continue
    fi

    kubectl -n ${NAMESPACE} patch volume ${VOL} \
      --type=json \
      -p '[{"op":"add","path":"/spec/recurringJobSelector/-","value":{"name":"nightly-backup","isGroup":false}}]'

    echo "  -> Job hinzugefügt."
done

echo
echo "=== Fertig ==="
echo "Alle Volumes haben jetzt (oder behalten):"
echo "- tägliches Backup um 03:00"
echo "- nur die letzten 3 Backups"
echo "- Zuweisung über recurringJobSelector (neue Methode)"
echo
echo "Script kann beliebig oft ausgeführt werden."
