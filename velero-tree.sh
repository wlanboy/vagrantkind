#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.sh
source "${SCRIPT_DIR}/versions.sh"

S5CMD="s5cmd"

# ── Env-Variablen prüfen ─────────────────────────────────────────────────────
for VAR in GARAGE_ACCESS_KEY GARAGE_SECRET_KEY GARAGE_ENDPOINT GARAGE_BUCKET GARAGE_REGION; do
  if [ -z "${!VAR:-}" ]; then
    echo "❌ Umgebungsvariable $VAR ist nicht gesetzt." >&2
    exit 1
  fi
done

export AWS_ACCESS_KEY_ID="${GARAGE_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${GARAGE_SECRET_KEY}"
export AWS_DEFAULT_REGION="${GARAGE_REGION}"
S5="${S5CMD} --endpoint-url ${GARAGE_ENDPOINT}"

# ── Hilfsfunktionen ──────────────────────────────────────────────────────────
human_size() {
  local bytes=$1
  if   [ "${bytes}" -ge $((1024*1024*1024)) ]; then
    printf "%.1f GB" "$(echo "scale=1; ${bytes}/1073741824" | bc)"
  elif [ "${bytes}" -ge $((1024*1024)) ]; then
    printf "%.1f MB" "$(echo "scale=1; ${bytes}/1048576" | bc)"
  elif [ "${bytes}" -ge 1024 ]; then
    printf "%.1f KB" "$(echo "scale=1; ${bytes}/1024" | bc)"
  else
    printf "%d B" "${bytes}"
  fi
}

# Listet alle Objekte rekursiv unterhalb eines Pfades und summiert deren Größe
# Gibt "ANZAHL BYTES" zurück
sum_prefix() {
  local prefix=$1
  ${S5} ls "s3://${GARAGE_BUCKET}/${prefix}*" 2>/dev/null \
    | awk 'NF >= 2 && $(NF-1) ~ /^[0-9]+$/ {sum += $(NF-1); count++} END {print count+0, sum+0}' || true
}

# ── Bucket erreichbar? ───────────────────────────────────────────────────────
if ! ${S5} ls "s3://${GARAGE_BUCKET}" &>/dev/null; then
  echo "❌ Bucket '${GARAGE_BUCKET}' nicht erreichbar." >&2
  exit 1
fi

echo "Velero Bucket: s3://${GARAGE_BUCKET}  (${GARAGE_ENDPOINT})"
echo "═══════════════════════════════════════════════════════════════"

# ── Top-Level-Verzeichnisse im Bucket ermitteln ──────────────────────────────
# Velero legt Backups unter backups/<name>/ ab, Logs unter backups/<name>/velero-backup.json etc.
# Wir listen alle "Ordner" auf erster Ebene
PREFIXES=$(${S5} ls "s3://${GARAGE_BUCKET}/" 2>/dev/null \
  | awk '/DIR/ {print $NF}' | sed "s|s3://${GARAGE_BUCKET}/||")

if [ -z "${PREFIXES}" ]; then
  echo "(Bucket ist leer – noch keine Backups vorhanden)"
  echo ""
  # Prüfen ob es FailedValidation-Backups in Kubernetes gibt
  FAILED_VAL=$(kubectl get backups -n velero \
    -o jsonpath='{range .items[*]}{.status.phase}={.metadata.name}{"\n"}{end}' 2>/dev/null \
    | grep '^FailedValidation=' | cut -d'=' -f2 || true)
  if [ -n "${FAILED_VAL}" ]; then
    echo "ℹ️  Grund: Es gibt Backups mit Status FailedValidation in Kubernetes."
    echo "   Diese schreiben keine Daten nach S3 – daher ist der Bucket leer."
    echo ""
    echo "   Kaputte Backups aufräumen:"
    while IFS= read -r name; do
      echo "     velero backup delete ${name} --confirm"
    done <<< "${FAILED_VAL}"
    echo ""
    echo "   Danach manuell ein Backup starten:"
    echo "     velero backup create --from-schedule ${SCHEDULE_NAME:-daily-backup} --wait"
    echo ""
    echo "   Oder erst den node-agent prüfen (häufigste Ursache für FailedValidation):"
    echo "     kubectl get daemonset node-agent -n velero"
    echo "     kubectl get pods -n velero -l name=node-agent"
  fi
  exit 0
fi

BUCKET_TOTAL=0

while IFS= read -r prefix; do
  # Zweite Ebene: Backup-Namen unter backups/
  trimmed="${prefix%/}"
  echo "📁 ${trimmed}/"

  SUBPREFIXES=$(${S5} ls "s3://${GARAGE_BUCKET}/${prefix}" 2>/dev/null \
    | awk '/DIR/ {print $NF}' | sed "s|^|${prefix}|")

  if [ -z "${SUBPREFIXES}" ]; then
    # Kein Unterverzeichnis – direkte Objekte (z. B. kopia-repo auf Root-Ebene)
    read -r COUNT BYTES <<< "$(sum_prefix "${prefix}")"
    HUMAN=$(human_size "${BYTES}")
    BUCKET_TOTAL=$((BUCKET_TOTAL + BYTES))
    printf "   (%-5s Dateien, %s)\n" "${COUNT}" "${HUMAN}"
    continue
  fi

  PREFIX_TOTAL=0
  while IFS= read -r sub; do
    sub_name=$(basename "${sub%/}")

    SUBSUBPREFIXES=$(${S5} ls "s3://${GARAGE_BUCKET}/${sub}" 2>/dev/null \
      | awk '/DIR/ {print $NF}' | sed "s|^|${sub}|" || true)

    if [ -z "${SUBSUBPREFIXES}" ]; then
      read -r COUNT BYTES <<< "$(sum_prefix "${sub}")"
      HUMAN=$(human_size "${BYTES}")
      PREFIX_TOTAL=$((PREFIX_TOTAL + BYTES))
      printf "   ├── %-52s %6s  (%s Dateien)\n" "${sub_name}" "${HUMAN}" "${COUNT}"
    else
      printf "   ├── %s/\n" "${sub_name}"
      SUB_TOTAL=0
      while IFS= read -r subsub; do
        subsub_name=$(basename "${subsub%/}")
        read -r COUNT BYTES <<< "$(sum_prefix "${subsub}")"
        HUMAN=$(human_size "${BYTES}")
        SUB_TOTAL=$((SUB_TOTAL + BYTES))
        printf "   │   ├── %-48s %6s  (%s Dateien)\n" "${subsub_name}" "${HUMAN}" "${COUNT}"
      done <<< "${SUBSUBPREFIXES}"
      PREFIX_TOTAL=$((PREFIX_TOTAL + SUB_TOTAL))
      printf "   │   └── %-48s %6s\n" "(gesamt)" "$(human_size "${SUB_TOTAL}")"
    fi
  done <<< "${SUBPREFIXES}"

  BUCKET_TOTAL=$((BUCKET_TOTAL + PREFIX_TOTAL))
  PREFIX_HUMAN=$(human_size "${PREFIX_TOTAL}")
  printf "   └── %-52s %6s\n" "(gesamt)" "${PREFIX_HUMAN}"
  echo ""
done <<< "${PREFIXES}"

echo "═══════════════════════════════════════════════════════════════"
printf "Bucket gesamt: %s\n" "$(human_size "${BUCKET_TOTAL}")"
