#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.sh
source "${SCRIPT_DIR}/versions.sh"

VELERO="velero"
SCHEDULE_NAME="daily-backup"
ERRORS=0
WARNINGS=0

fail()    { echo "❌ $*"; ((ERRORS++))  || true; }
warn()    { echo "⚠️  $*"; ((WARNINGS++)) || true; }
ok()      { echo "✅ $*"; }
section() { echo ""; echo "── $* ──────────────────────────────────────"; }

# ── 1. Velero Pod läuft ─────────────────────────────────────────────────────
section "Velero Deployment"
READY=$(kubectl get deployment velero -n velero \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${READY}" -ge 1 ] 2>/dev/null; then
  ok "Velero Deployment bereit (${READY} Replika(s))"
else
  fail "Velero Deployment nicht bereit (readyReplicas=${READY})"
fi

# ── 2. BackupStorageLocation erreichbar ────────────────────────────────────
section "BackupStorageLocation"
BSL_STATUS=$(kubectl get backupstoragelocation -n velero \
  -o jsonpath='{range .items[*]}{.metadata.name}={.status.phase}{"\n"}{end}' 2>/dev/null || true)
if [ -z "${BSL_STATUS}" ]; then
  fail "Keine BackupStorageLocation gefunden"
else
  while IFS='=' read -r name phase; do
    if [ "${phase}" = "Available" ]; then
      ok "BSL '${name}': ${phase}"
    else
      fail "BSL '${name}': ${phase} (erwartet: Available)"
    fi
  done <<< "${BSL_STATUS}"
fi

# ── 3. Schedule vorhanden und aktiv ────────────────────────────────────────
section "Backup Schedule '${SCHEDULE_NAME}'"
SCHEDULE_EXISTS=$(kubectl get schedule "${SCHEDULE_NAME}" -n velero --ignore-not-found -o name 2>/dev/null || echo "")
if [ -z "${SCHEDULE_EXISTS}" ]; then
  fail "Schedule '${SCHEDULE_NAME}' nicht gefunden"
else
  SCHEDULE_PHASE=$(kubectl get schedule "${SCHEDULE_NAME}" -n velero \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  LAST_BACKUP=$(kubectl get schedule "${SCHEDULE_NAME}" -n velero \
    -o jsonpath='{.status.lastBackupTime}' 2>/dev/null || echo "")
  ok "Schedule '${SCHEDULE_NAME}' vorhanden (phase=${SCHEDULE_PHASE:-Enabled})"
  if [ -n "${LAST_BACKUP}" ]; then
    ok "Letzter Schedule-Lauf: ${LAST_BACKUP}"
  else
    warn "Schedule '${SCHEDULE_NAME}' wurde noch nie ausgeführt"
    echo "   Backup jetzt manuell starten:"
    echo "     velero backup create --from-schedule ${SCHEDULE_NAME} --wait"
  fi
fi

# ── 4. Node-Agent (kopia) DaemonSet ────────────────────────────────────────
section "Node-Agent (kopia) DaemonSet"
NA_DESIRED=$(kubectl get daemonset node-agent -n velero \
  -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "")
if [ -z "${NA_DESIRED}" ]; then
  fail "node-agent DaemonSet nicht gefunden (aber defaultVolumesToFsBackup=true im Schedule)"
else
  NA_READY=$(kubectl get daemonset node-agent -n velero \
    -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  if [ "${NA_READY}" -eq "${NA_DESIRED}" ] && [ "${NA_DESIRED}" -gt 0 ]; then
    ok "node-agent DaemonSet: ${NA_READY}/${NA_DESIRED} Pods bereit"
  else
    fail "node-agent DaemonSet: nur ${NA_READY}/${NA_DESIRED} Pods bereit"
  fi
fi

# ── 5. Aktuelle Backups prüfen ─────────────────────────────────────────────
section "Backup Status (letzte 10)"
BACKUPS=$(kubectl get backups -n velero \
  --sort-by='.metadata.creationTimestamp' \
  -o jsonpath='{range .items[*]}{.metadata.name}={.status.phase}{"\n"}{end}' 2>/dev/null || true)

if [ -z "${BACKUPS}" ]; then
  warn "Keine Backups gefunden – wurde der Schedule schon einmal ausgeführt?"
else
  TOTAL=0; COMPLETED=0; FAILED=0; PARTIAL=0; IN_PROGRESS=0; VALIDATION=0
  while IFS='=' read -r name phase; do
    ((TOTAL++)) || true
    case "${phase}" in
      Completed)         ((COMPLETED++))   || true; ok "  ${name}: ${phase}" ;;
      PartiallyFailed)   ((PARTIAL++))     || true; warn "  ${name}: ${phase}" ;;
      Failed)            ((FAILED++))      || true; fail "  ${name}: ${phase}" ;;
      FailedValidation)  ((VALIDATION++))  || true; fail "  ${name}: ${phase}" ;;
      InProgress)        ((IN_PROGRESS++)) || true; echo "⏳  ${name}: ${phase}" ;;
      *)                 warn "  ${name}: ${phase} (unbekannt)" ;;
    esac
  done <<< "$(echo "${BACKUPS}" | tail -10)"

  echo ""
  echo "   Gesamt: ${TOTAL} | Completed: ${COMPLETED} | Failed: ${FAILED} | FailedValidation: ${VALIDATION} | PartiallyFailed: ${PARTIAL} | InProgress: ${IN_PROGRESS}"

  if [ "${FAILED}" -gt 0 ] || [ "${PARTIAL}" -gt 0 ] || [ "${VALIDATION}" -gt 0 ]; then
    echo ""
    echo "   Details zu fehlgeschlagenen Backups:"
    while IFS='=' read -r name phase; do
      if [[ "${phase}" == "Failed" || "${phase}" == "PartiallyFailed" || "${phase}" == "FailedValidation" ]]; then
        REASONS=$(kubectl get backup "${name}" -n velero \
          -o jsonpath='{range .status.validationErrors[*]}{.}{"\n"}{end}' 2>/dev/null \
          | sed 's/^/         - /' || true)
        MSG=$(kubectl get backup "${name}" -n velero \
          -o jsonpath='{.status.failureReason}' 2>/dev/null || true)
        echo "   → ${name} (${phase}):"
        [ -n "${REASONS}" ] && echo "${REASONS}"
        [ -n "${MSG}" ]     && echo "         Reason: ${MSG}"
        [ -z "${REASONS}" ] && [ -z "${MSG}" ] && \
          echo "         (keine Details – prüfe: velero backup describe ${name})"
      fi
    done <<< "${BACKUPS}"

    echo ""
    echo "   Aufräumen (kaputte Backups löschen):"
    while IFS='=' read -r name phase; do
      if [[ "${phase}" == "Failed" || "${phase}" == "PartiallyFailed" || "${phase}" == "FailedValidation" ]]; then
        echo "     velero backup delete ${name} --confirm"
      fi
    done <<< "${BACKUPS}"
  fi
fi

# ── 6. Letztes Backup nicht zu alt ─────────────────────────────────────────
section "Aktualität des letzten Backups"
LAST_COMPLETED=$(kubectl get backups -n velero \
  --sort-by='.metadata.creationTimestamp' \
  -o jsonpath='{range .items[*]}{.status.phase}={.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null \
  | grep '^Completed=' | tail -1 | cut -d'=' -f2 || echo "")

if [ -z "${LAST_COMPLETED}" ]; then
  warn "Kein erfolgreiches Backup gefunden"
else
  NOW_EPOCH=$(date +%s)
  LAST_EPOCH=$(date -d "${LAST_COMPLETED}" +%s 2>/dev/null || echo "0")
  AGE_HOURS=$(( (NOW_EPOCH - LAST_EPOCH) / 3600 ))
  if [ "${AGE_HOURS}" -le 26 ]; then
    ok "Letztes erfolgreiches Backup vor ${AGE_HOURS}h (${LAST_COMPLETED})"
  elif [ "${AGE_HOURS}" -le 50 ]; then
    warn "Letztes erfolgreiches Backup vor ${AGE_HOURS}h – Schedule evtl. übersprungen?"
  else
    fail "Letztes erfolgreiches Backup vor ${AGE_HOURS}h – möglicherweise defekter Schedule!"
  fi
fi

# ── 7. VolumeSnapshotLocation (optional) ───────────────────────────────────
section "VolumeSnapshotLocation (optional)"
VSL=$(kubectl get volumesnapshotlocation -n velero \
  -o jsonpath='{range .items[*]}{.metadata.name}={.status.phase}{"\n"}{end}' 2>/dev/null || true)
if [ -z "${VSL}" ]; then
  echo "   (keine VolumeSnapshotLocation konfiguriert – nur File-System-Backup aktiv)"
else
  while IFS='=' read -r name phase; do
    if [ "${phase}" = "Available" ]; then
      ok "VSL '${name}': ${phase}"
    else
      warn "VSL '${name}': ${phase}"
    fi
  done <<< "${VSL}"
fi

# ── Zusammenfassung ─────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
if [ "${ERRORS}" -eq 0 ] && [ "${WARNINGS}" -eq 0 ]; then
  echo "✅ Velero Check: Alles OK"
elif [ "${ERRORS}" -eq 0 ]; then
  echo "⚠️  Velero Check: OK mit ${WARNINGS} Warnung(en)"
else
  echo "❌ Velero Check: ${ERRORS} Fehler, ${WARNINGS} Warnung(en)"
fi
echo "════════════════════════════════════════════════════"

[ "${ERRORS}" -eq 0 ]
