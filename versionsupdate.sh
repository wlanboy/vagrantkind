#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="$SCRIPT_DIR/versions.sh"

source "$VERSIONS_FILE"

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

UPDATES=0
DRY_RUN=true
SKIP_TOOLS=""

# Argumente parsen
for arg in "$@"; do
  case "$arg" in
    --apply) DRY_RUN=false ;;
    --skip=*) SKIP_TOOLS="${SKIP_TOOLS} ${arg#--skip=}" ;;
    --help)
      echo "Nutzung: $0 [--apply] [--skip=tool1,tool2,...]"
      echo ""
      echo "  --apply             Versionen in versions.sh aktualisieren"
      echo "  --skip=helm,istio   Tools vom Update ausschließen"
      echo ""
      echo "Verfügbare Tools: helm, kind, istio, k9s, argocd"
      exit 0
      ;;
  esac
done

# Komma-getrennte Skip-Liste in prüfbaren String umwandeln
SKIP_TOOLS=$(echo "$SKIP_TOOLS" | tr ',' ' ')

is_skipped() {
  local tool="$1"
  for skip in $SKIP_TOOLS; do
    if [ "$skip" = "$tool" ]; then
      echo -e "  ${YELLOW}übersprungen (--skip)${NC}"
      return 0
    fi
  done
  return 1
}

# Ermittelt die neueste GitHub-Release-Version (ohne v-Prefix)
github_latest() {
  local repo="$1"
  curl -sL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oP '"tag_name":\s*"v?\K[^"]+' \
    | head -1
}

# Ermittelt die neueste GitHub-Release-Version (mit v-Prefix)
github_latest_raw() {
  local repo="$1"
  curl -sL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oP '"tag_name":\s*"\K[^"]+' \
    | head -1
}

# Aktualisiert eine Variable in versions.sh
update_version() {
  local var="$1"
  local old="$2"
  local new="$3"

  if [ "$old" = "$new" ]; then
    echo -e "  ${GREEN}$var${NC} ist aktuell: $old"
    return
  fi

  UPDATES=$((UPDATES + 1))

  if $DRY_RUN; then
    echo -e "  ${YELLOW}$var${NC} $old -> $new"
  else
    sed -i "s|^${var}=\"${old}\"|${var}=\"${new}\"|" "$VERSIONS_FILE"
    echo -e "  ${GREEN}$var${NC} aktualisiert: $old -> $new"
  fi
}

echo "Prüfe auf neue Versionen..."
echo ""

# --- Helm ---
echo "Helm (helm/helm):"
if ! is_skipped helm; then
  HELM_LATEST=$(github_latest "helm/helm")
  update_version "HELM_VERSION" "$HELM_VERSION" "$HELM_LATEST"
fi

# --- Kind ---
echo "Kind (kubernetes-sigs/kind):"
if ! is_skipped kind; then
  KIND_LATEST=$(github_latest "kubernetes-sigs/kind")
  update_version "KIND_VERSION" "$KIND_VERSION" "$KIND_LATEST"
fi

# --- Istio ---
echo "Istio (istio/istio):"
if ! is_skipped istio; then
  ISTIO_LATEST=$(github_latest "istio/istio")
  update_version "ISTIO_VERSION" "$ISTIO_VERSION" "$ISTIO_LATEST"
fi

# --- K9s ---
echo "K9s (derailed/k9s):"
if ! is_skipped k9s; then
  K9S_LATEST=$(github_latest "derailed/k9s")
  update_version "K9S_VERSION" "$K9S_VERSION" "$K9S_LATEST"
fi

# --- ArgoCD (behält v-Prefix) ---
echo "ArgoCD (argoproj/argo-cd):"
if ! is_skipped argocd; then
  ARGOCD_LATEST=$(github_latest_raw "argoproj/argo-cd")
  update_version "ARGOCD_VERSION" "$ARGOCD_VERSION" "$ARGOCD_LATEST"
fi

echo ""
if [ $UPDATES -eq 0 ]; then
  echo -e "${GREEN}Alle Versionen sind aktuell.${NC}"
elif $DRY_RUN; then
  echo -e "${YELLOW}$UPDATES Update(s) verfügbar.${NC}"
  echo "Zum Anwenden:  $0 --apply"
else
  echo -e "${GREEN}$UPDATES Version(en) in versions.sh aktualisiert.${NC}"
fi
