#!/bin/bash
# Hilfsfunktionen für Tool-Installation

# Ermittelt die installierte Version eines Tools, oder "" falls nicht vorhanden
installed_version() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    echo ""
    return
  fi
  case "$cmd" in
    kubectl)   kubectl version --client -o json 2>/dev/null | grep -oP '"gitVersion":\s*"v?\K[^"]+' ;;
    helm)      helm version --short 2>/dev/null | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' ;;
    kind)      kind version 2>/dev/null | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' ;;
    istioctl)  istioctl version --remote=false 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 ;;
    k9s)       k9s version --short 2>/dev/null | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' ;;
    argocd)    argocd version --client -o json 2>/dev/null | grep -oP '"Version":\s*"v?\K[^"]+' ;;
    hey)       echo "installed" ;;
    mirrord)   mirrord --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' ;;
    uv)        uv --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' ;;
    code)      code --version 2>/dev/null | head -1 ;;
    *)         echo "" ;;
  esac
}

# Prüft ob ein apt-Paket installiert ist
is_apt_installed() {
  dpkg -s "$1" &>/dev/null
}

# Prüft ob eine SDK-Candidate-Version installiert ist (sdkman)
sdk_need_install() {
  local candidate="$1"
  local want="$2"
  if [ ! -d "$HOME/.sdkman/candidates/$candidate/$want" ]; then
    echo "  $candidate $want ist nicht installiert -> wird installiert"
    return 0
  fi
  echo "  $candidate $want ist bereits installiert -> übersprungen"
  return 1
}

# Prüft ob eine Datei/AppImage existiert
need_file() {
  local path="$1"
  local name="$2"
  if [ -f "$path" ]; then
    echo "  $name ist bereits vorhanden -> übersprungen"
    return 1
  fi
  echo "  $name ist nicht vorhanden -> wird installiert"
  return 0
}

need_install() {
  local cmd="$1"
  local want="$2"
  local have
  have=$(installed_version "$cmd")
  if [ -z "$have" ]; then
    echo "  $cmd ist nicht installiert -> wird installiert"
    return 0
  fi
  if [ "$have" = "installed" ]; then
    echo "  $cmd ist bereits installiert -> übersprungen"
    return 1
  fi
  if [ "$have" = "$want" ]; then
    echo "  $cmd ist bereits in Version $want installiert -> übersprungen"
    return 1
  fi
  echo "  $cmd Version $have -> wird auf $want aktualisiert"
  return 0
}
