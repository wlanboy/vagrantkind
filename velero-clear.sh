#!/usr/bin/env bash
set -euo pipefail

SCHEDULE_NAME="daily-backup"
ERRORS=0

fail() { echo "❌ $*"; ((ERRORS++)) || true; }
ok()   { echo "✅ $*"; }
info() { echo "ℹ️  $*"; }

echo "🧹 Velero Aufräumen..."
echo "════════════════════════════════════════════════════"

# ── 1. Laufende/hängende Backups abbrechen ──────────────────────────────────
echo ""
echo "── InProgress / New Backups ────────────────────────"
INPROGRESS=$(kubectl get backups -n velero \
  -o jsonpath='{range .items[*]}{.status.phase}={.metadata.name}{"\n"}{end}' 2>/dev/null \
  | grep -E '^(InProgress|New)=' | cut -d'=' -f2 || true)

if [ -n "${INPROGRESS}" ]; then
  while IFS= read -r name; do
    echo "   Breche ab: ${name}"
    velero backup delete "${name}" --confirm 2>/dev/null && ok "  ${name} gelöscht" || fail "  ${name} konnte nicht gelöscht werden"
  done <<< "${INPROGRESS}"
else
  info "Keine laufenden Backups"
fi

# ── 2. Kaputte Backups löschen ──────────────────────────────────────────────
echo ""
echo "── Failed / FailedValidation Backups ───────────────"
BROKEN=$(kubectl get backups -n velero \
  -o jsonpath='{range .items[*]}{.status.phase}={.metadata.name}{"\n"}{end}' 2>/dev/null \
  | grep -E '^(Failed|FailedValidation|PartiallyFailed)=' | cut -d'=' -f2 || true)

if [ -n "${BROKEN}" ]; then
  while IFS= read -r name; do
    velero backup delete "${name}" --confirm 2>/dev/null && ok "  ${name} gelöscht" || fail "  ${name} konnte nicht gelöscht werden"
  done <<< "${BROKEN}"
else
  info "Keine kaputten Backups"
fi

# ── 3. Verwaiste BackupRepositories löschen ─────────────────────────────────
echo ""
echo "── BackupRepositories (kopia) ──────────────────────"
REPOS=$(kubectl get backuprepository -n velero \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

if [ -n "${REPOS}" ]; then
  while IFS= read -r name; do
    kubectl delete backuprepository "${name}" -n velero 2>/dev/null && ok "  ${name} gelöscht" || fail "  ${name} konnte nicht gelöscht werden"
  done <<< "${REPOS}"
  info "Velero legt diese beim nächsten Backup neu an"
else
  info "Keine BackupRepositories vorhanden"
fi

# ── 4. Fehler-Pods im velero Namespace aufräumen ────────────────────────────
echo ""
echo "── Error Pods (kopia-maintain-jobs, Backup-Pods) ───"
ERROR_PODS=$(kubectl get pods -n velero \
  --field-selector=status.phase=Failed \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

if [ -n "${ERROR_PODS}" ]; then
  COUNT=$(echo "${ERROR_PODS}" | wc -l)
  kubectl delete pods -n velero --field-selector=status.phase=Failed 2>/dev/null \
    && ok "${COUNT} Error-Pod(s) gelöscht" \
    || fail "Error-Pods konnten nicht gelöscht werden"
else
  info "Keine Error-Pods"
fi

# ── Zusammenfassung ──────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
if [ "${ERRORS}" -eq 0 ]; then
  ok "Aufräumen abgeschlossen"
  echo ""
  echo "   Nächste Schritte:"
  echo "     velero backup create --from-schedule ${SCHEDULE_NAME} --wait"
  echo "     ./velero-check.sh"
  echo "     ./velero-tree.sh"
else
  fail "Aufräumen mit ${ERRORS} Fehler(n) abgeschlossen – prüfe die Ausgabe oben"
fi
echo "════════════════════════════════════════════════════"

[ "${ERRORS}" -eq 0 ]
