#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=versions.sh
source "${SCRIPT_DIR}/versions.sh"

# Garage S3-API läuft auf Port 3900 (dxflrs/garage)
S5CMD="s5cmd"

# --- Env-Variablen prüfen ---
echo "🔍 Prüfe Umgebungsvariablen..."
for VAR in GARAGE_ACCESS_KEY GARAGE_SECRET_KEY GARAGE_ENDPOINT GARAGE_ALIAS GARAGE_BUCKET GARAGE_REGION; do
  if [ -z "${!VAR}" ]; then
    echo "❌ Umgebungsvariable $VAR ist nicht gesetzt."
    exit 1
  fi
done
echo "✅ Alle Garage-Variablen vorhanden."

# --- AWS-Umgebungsvariablen für s5cmd setzen ---
export AWS_ACCESS_KEY_ID="${GARAGE_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${GARAGE_SECRET_KEY}"
export AWS_DEFAULT_REGION="${GARAGE_REGION}"
S5="${S5CMD} --endpoint-url ${GARAGE_ENDPOINT}"

VELERO="velero"

# --- Garage Bucket prüfen / anlegen ---
echo "🪣 Prüfe Garage Bucket '${GARAGE_BUCKET}'..."
if ! ${S5} ls "s3://${GARAGE_BUCKET}" &>/dev/null; then
  echo "📦 Erstelle Garage Bucket '${GARAGE_BUCKET}'..."
  ${S5} mb "s3://${GARAGE_BUCKET}"
  echo "✅ Bucket '${GARAGE_BUCKET}' erstellt."
else
  echo "✅ Bucket '${GARAGE_BUCKET}' bereits vorhanden."
fi

# --- Namespace ---
echo "📁 Erstelle Velero Namespace..."
kubectl apply -f manifests/velero/namespace.yaml

# --- Credentials Secret ---
echo "🔑 Erstelle Garage Credentials Secret..."
kubectl create secret generic velero-credentials \
  --namespace velero \
  --from-literal=cloud="[default]
aws_access_key_id=${GARAGE_ACCESS_KEY}
aws_secret_access_key=${GARAGE_SECRET_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

# --- Velero via Helm installieren ---
helm repo add velero https://vmware-tanzu.github.io/helm-charts --force-update
helm repo update velero

echo "🚀 Installiere/Aktualisiere Velero..."
helm upgrade --install velero velero/velero \
  -f manifests/velero/velero-values.yaml \
  --set configuration.backupStorageLocation[0].config.s3Url="${GARAGE_ENDPOINT}" \
  --set configuration.backupStorageLocation[0].config.region="${GARAGE_REGION}" \
  --set configuration.backupStorageLocation[0].bucket="${GARAGE_BUCKET}" \
  --set initContainers[0].image="velero/velero-plugin-for-aws:${VELERO_AWS_PLUGIN_VERSION}" \
  -n velero

echo "⏳ Warte auf Velero Pods..."
kubectl wait --namespace velero \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/name=velero \
  --timeout=180s

# --- Backup Schedule ---
SCHEDULE_NAME="daily-backup"
echo "📅 Erstelle/Aktualisiere täglichen Backup-Schedule..."
kubectl apply -f manifests/velero/schedule.yaml
echo "✅ Backup-Schedule '${SCHEDULE_NAME}' angelegt."

echo ""
echo "🎉 Velero Setup abgeschlossen!"
echo "   Garage Endpoint:     ${GARAGE_ENDPOINT}"
echo "   Garage Region:       ${GARAGE_REGION}"
echo "   Garage Bucket:       ${GARAGE_BUCKET}"
echo ""
echo "   Backup erstellen (Namespace):"
echo "     velero backup create monitoring-backup \\"
echo "       --include-namespaces monitoring \\"
echo "       --ttl 168h \\"
echo "       --wait"
echo ""
echo "   Backups anzeigen:    velero backup get"
echo "   Backup-Details:      velero backup describe monitoring-backup"
echo "   Backup-Logs:         velero backup logs monitoring-backup"
echo ""
echo "   Backup löschen:"
echo "     velero backup delete monitoring-backup --confirm"
echo ""
echo "   Restore (Namespace):"
echo "     velero restore create --from-backup monitoring-backup \\"
echo "       --include-namespaces monitoring \\"
echo "       --wait"
echo "     velero restore get"
echo ""
echo "   Schedule manuell anstoßen:"
echo "     velero backup create --from-schedule ${SCHEDULE_NAME} --wait"
echo ""
echo "   Disaster Recovery (Restore aus Full-Backup):"
echo "     velero restore create --from-schedule ${SCHEDULE_NAME} --wait"
echo "     velero restore get"
echo ""

