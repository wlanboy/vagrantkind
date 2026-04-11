#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Farben für Ausgabe ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- WSL-Erkennung ---
IS_WSL=false
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
info() { echo -e "${YELLOW}[..] $*${NC}"; }
err()  { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

# --- whiptail prüfen / installieren ---
if ! command -v whiptail &>/dev/null; then
    echo "whiptail nicht gefunden – wird installiert..."
    sudo apt-get install -y whiptail || err "whiptail konnte nicht installiert werden."
fi

# --- Bildschirmgröße ---
ROWS=$(tput lines)
COLS=$(tput cols)
H=$(( ROWS > 24 ? 24 : ROWS - 2 ))
W=$(( COLS > 80 ? 80 : COLS - 4 ))

# ===========================================================================
# 1. Willkommensbildschirm
# ===========================================================================
whiptail --title "Kubernetes Installer" --msgbox \
"Willkommen beim interaktiven Kubernetes-Installer!

Dieses Script richtet einen lokalen Kubernetes-Cluster ein und
installiert optional weitere Komponenten:

  • Cluster-Backend:  k3s  oder  kind (+ Docker)
  • MetalLB          – LoadBalancer für bare-metal
  • cert-manager     – TLS-Zertifikatsverwaltung
  • Istio            – Service Mesh
  • ArgoCD           – GitOps Continuous Delivery

Im nächsten Schritt werden Sie durch alle Optionen geführt.
Jede Frage kann mit den Pfeiltasten und Enter beantwortet werden." \
$H $W

# ===========================================================================
# 2. CLI-Tools installieren?
# ===========================================================================
TOOL_LIST="\
  kubectl    – Kubernetes CLI
  helm       – Paketmanager für Kubernetes
  kind       – Kubernetes-in-Docker (lokale Cluster)
  istioctl   – Istio Service Mesh CLI
  k9s        – Terminal-UI für Kubernetes
  argocd     – ArgoCD CLI
  hey        – HTTP-Load-Testing-Tool
  mirrord    – Remote-Debugging in Kubernetes"

if whiptail --title "CLI-Tools" --yesno \
"Sollen die folgenden CLI-Tools via amd64-tools.sh installiert werden?

${TOOL_LIST}

(Bereits installierte Tools werden übersprungen)" \
$H $W; then
    INSTALL_TOOLS=true
else
    INSTALL_TOOLS=false
fi

# ===========================================================================
# 3. Cluster-Backend wählen
# ===========================================================================
CLUSTER_CHOICE=$(whiptail --title "Cluster-Backend" --radiolist \
"Welches Cluster-Backend soll verwendet werden?" \
$H $W 2 \
"k3s"  "Leichtgewichtiges Kubernetes (kein Docker nötig)" ON \
"kind" "Kubernetes-in-Docker (Docker wird zuerst eingerichtet)" OFF \
3>&1 1>&2 2>&3) || err "Abgebrochen."

# ===========================================================================
# 4. Optionale Komponenten
# ===========================================================================
INSTALL_METALLB=false
INSTALL_CERTMANAGER=false
INSTALL_ISTIO=false
INSTALL_ARGOCD=false

if whiptail --title "MetalLB" --yesno \
"MetalLB installieren?

MetalLB ist ein LoadBalancer-Controller für bare-metal Kubernetes-Cluster.
Er weist Services vom Typ 'LoadBalancer' echte IP-Adressen zu." \
$H $W; then
    INSTALL_METALLB=true
fi

if whiptail --title "cert-manager" --yesno \
"cert-manager installieren?

cert-manager automatisiert die Ausstellung und Erneuerung von
TLS-Zertifikaten (z. B. über Let's Encrypt oder eine eigene CA)." \
$H $W; then
    INSTALL_CERTMANAGER=true
fi

if whiptail --title "Istio" --yesno \
"Istio Service Mesh installieren?

Istio bietet Traffic-Management, mTLS, Observability und
feingranulare Zugriffsrichtlinien zwischen Services." \
$H $W; then
    INSTALL_ISTIO=true
fi

if whiptail --title "ArgoCD" --yesno \
"ArgoCD installieren?

ArgoCD ist ein deklarativer GitOps-Controller für Kubernetes.
Er synchronisiert Cluster-Zustand automatisch mit einem Git-Repository." \
$H $W; then
    INSTALL_ARGOCD=true
fi

# ===========================================================================
# 5. Zusammenfassung
# ===========================================================================
SUMMARY="Folgende Schritte werden jetzt ausgeführt:\n\n"
[[ "$INSTALL_TOOLS"       == true ]] && SUMMARY+="  [x] CLI-Tools installieren (amd64-tools.sh)\n"
[[ "$CLUSTER_CHOICE"      == "k3s"  ]] && SUMMARY+="  [x] k3s Cluster (install-local-k3s.sh)\n"
if [[ "$CLUSTER_CHOICE" == "kind" ]]; then
    SUMMARY+="  [x] Docker einrichten (docker.sh)\n"
    SUMMARY+="  [x] kind Cluster (install-local-kind.sh)\n"
fi
[[ "$INSTALL_METALLB"     == true ]] && SUMMARY+="  [x] MetalLB (install-metallb.sh)\n"
[[ "$INSTALL_CERTMANAGER" == true ]] && SUMMARY+="  [x] cert-manager (install-certmanager.sh)\n"
[[ "$INSTALL_ISTIO"       == true ]] && SUMMARY+="  [x] Istio (install-istio.sh)\n"
[[ "$INSTALL_ARGOCD"      == true ]] && SUMMARY+="  [x] ArgoCD (install-argocd.sh)\n"

whiptail --title "Zusammenfassung" --yesno \
"${SUMMARY}\nJetzt starten?" \
$H $W || err "Installation abgebrochen."

# ===========================================================================
# 6. Ausführung
# ===========================================================================
echo ""
info "Starte Installation..."
echo ""

run_script() {
    local script="$SCRIPT_DIR/$1"
    if [[ ! -f "$script" ]]; then
        err "Script nicht gefunden: $script"
    fi
    info "Führe aus: $1"
    bash "$script"
    ok "$1 abgeschlossen."
    echo ""
}

if [[ "$INSTALL_TOOLS" == true ]]; then
    run_script "amd64-tools.sh"
fi

if [[ "$CLUSTER_CHOICE" == "kind" ]]; then
    run_script "docker.sh"
    if [[ "$IS_WSL" == true ]]; then
        info "WSL erkannt – verwende install-wsl-kind.sh"
        run_script "install-wsl-kind.sh"
    else
        run_script "install-local-kind.sh"
    fi
else
    run_script "install-local-k3s.sh"
fi

if [[ "$INSTALL_METALLB" == true ]]; then
    if [[ "$CLUSTER_CHOICE" == "kind" && "$IS_WSL" == true ]]; then
        run_script "install-wsl-metallb.sh"
    else
        run_script "install-metallb.sh"
    fi
fi

if [[ "$INSTALL_CERTMANAGER" == true ]]; then
    run_script "install-certmanager.sh"
fi

if [[ "$INSTALL_ISTIO" == true ]]; then
    run_script "install-istio.sh"
fi

if [[ "$INSTALL_ARGOCD" == true ]]; then
    run_script "install-argocd.sh"
fi

echo ""
ok "Installation abgeschlossen!"
