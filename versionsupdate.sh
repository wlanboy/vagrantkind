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
COMMIT=false
SKIP_TOOLS=""

# Argumente parsen
for arg in "$@"; do
  case "$arg" in
    --apply) DRY_RUN=false ;;
    --commit) DRY_RUN=false; COMMIT=true ;;
    --skip=*) SKIP_TOOLS="${SKIP_TOOLS} ${arg#--skip=}" ;;
    --help)
      echo "Nutzung: $0 [--apply|--commit] [--skip=tool1,tool2,...]"
      echo ""
      echo "  --apply             Versionen in versions.sh aktualisieren"
      echo "  --commit            Versionen aktualisieren und git commit erstellen"
      echo "  --skip=helm,istio   Tools vom Update ausschließen"
      echo ""
      echo "Verfügbare Tools: helm, kind, istio, k9s, argocd, metallb"
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

COMMIT_LOG=""

# Aktualisiert eine Variable in versions.sh
update_version() {
  local var="$1"
  local old="$2"
  local new="$3"

  if [ "$old" = "$new" ]; then
    echo -e "  ${GREEN}$var${NC} ist aktuell: $old"
    LAST_VERSION_MSG="  $var ist aktuell: $old"
    return
  fi

  UPDATES=$((UPDATES + 1))

  if $DRY_RUN; then
    echo -e "  ${YELLOW}$var${NC} $old -> $new"
    LAST_VERSION_MSG="  $var $old -> $new"
  else
    sed -i "s|^${var}=\"${old}\"|${var}=\"${new}\"|" "$VERSIONS_FILE"
    echo -e "  ${GREEN}$var${NC} aktualisiert: $old -> $new"
    LAST_VERSION_MSG="  $var $old -> $new"
  fi
}

echo "Prüfe auf neue Versionen..."
echo ""

# --- Helm ---
echo "Helm (helm/helm):"
if ! is_skipped helm; then
  HELM_LATEST=$(github_latest "helm/helm")
  update_version "HELM_VERSION" "$HELM_VERSION" "$HELM_LATEST"
  COMMIT_LOG+="Helm (helm/helm):\n$LAST_VERSION_MSG\n"
fi

# --- Kind ---
echo "Kind (kubernetes-sigs/kind):"
if ! is_skipped kind; then
  KIND_LATEST=$(github_latest "kubernetes-sigs/kind")
  update_version "KIND_VERSION" "$KIND_VERSION" "$KIND_LATEST"
  COMMIT_LOG+="Kind (kubernetes-sigs/kind):\n$LAST_VERSION_MSG\n"
fi

# --- Istio ---
echo "Istio (istio/istio):"
if ! is_skipped istio; then
  ISTIO_LATEST=$(github_latest "istio/istio")
  update_version "ISTIO_VERSION" "$ISTIO_VERSION" "$ISTIO_LATEST"
  COMMIT_LOG+="Istio (istio/istio):\n$LAST_VERSION_MSG\n"
fi

# --- K9s ---
echo "K9s (derailed/k9s):"
if ! is_skipped k9s; then
  K9S_LATEST=$(github_latest "derailed/k9s")
  update_version "K9S_VERSION" "$K9S_VERSION" "$K9S_LATEST"
  COMMIT_LOG+="K9s (derailed/k9s):\n$LAST_VERSION_MSG\n"
fi

# --- ArgoCD (behält v-Prefix) ---
echo "ArgoCD (argoproj/argo-cd):"
if ! is_skipped argocd; then
  ARGOCD_LATEST=$(github_latest_raw "argoproj/argo-cd")
  update_version "ARGOCD_VERSION" "$ARGOCD_VERSION" "$ARGOCD_LATEST"
  COMMIT_LOG+="ArgoCD (argoproj/argo-cd):\n$LAST_VERSION_MSG\n"
fi

# --- MetalLB ---
echo "MetalLB (metallb/metallb):"
if ! is_skipped metallb; then
  METALLB_LATEST=$(github_latest "metallb/metallb")
  update_version "METALLB_VERSION" "$METALLB_VERSION" "$METALLB_LATEST"
  COMMIT_LOG+="MetalLB (metallb/metallb):\n$LAST_VERSION_MSG\n"
fi

echo ""
if [ $UPDATES -eq 0 ]; then
  echo -e "${GREEN}Alle Versionen sind aktuell.${NC}"
  if $COMMIT; then
    echo "Keine Änderungen – kein Commit erstellt."
  fi
elif $DRY_RUN; then
  echo -e "${YELLOW}$UPDATES Update(s) verfügbar.${NC}"
  echo "Zum Anwenden:  $0 --apply"
  echo "Mit Commit:    $0 --commit"
  echo ""
  read -r -p "Jetzt ./versionsupdate.sh --commit ausführen? [y/N] " ANSWER
  if [[ "${ANSWER,,}" == "y" ]]; then
    exec "$0" --commit
  fi
else
  echo -e "${GREEN}$UPDATES Version(en) in versions.sh aktualisiert.${NC}"
  if $COMMIT; then
    git -C "$SCRIPT_DIR" add versions.sh
    git -C "$SCRIPT_DIR" commit -m "$(printf '%b' "$COMMIT_LOG")"
    echo ""
    echo -e "${GREEN}Commit erstellt.${NC} Du kannst jetzt pushen:"
    echo "  git push"
  fi
fi
