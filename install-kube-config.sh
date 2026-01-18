#!/bin/bash
set -euo pipefail

# ----------------------------------------------------------------------
# 1. KONFIGURATION
# ----------------------------------------------------------------------
SSH_USER="${1:-$USER}"
SERVER="${2:-gmk}"
REMOTE_K3S_PATH="/home/$SSH_USER/.kube/k3s.yaml"
LOCAL_K3S_PATH="$HOME/.kube/k3s-remote-temp.yaml"
LOCAL_KUBECONFIG="$HOME/.kube/config"

# Prüfen ob benötigte Tools vorhanden sind
for cmd in kubectl scp ping; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd ist nicht installiert"
        exit 1
    fi
done

# Server-IP ermitteln
echo "1. Ermittle IP für $SERVER..."
if ! SERVER_IP=$(ping -c 1 "$SERVER" 2>/dev/null | head -n 1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n 1); then
    echo "Fehler: Konnte $SERVER nicht auflösen"
    exit 1
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "Fehler: Keine IP für $SERVER gefunden"
    exit 1
fi
echo "   -> IP: $SERVER_IP"

# ----------------------------------------------------------------------
# 2. ÜBERTRAGEN DER KUBECONFIG VOM SERVER
# ----------------------------------------------------------------------
echo "2. Lade Kubeconfig via SSH/SCP von $SSH_USER@$SERVER..."

if ! scp "$SSH_USER@$SERVER:$REMOTE_K3S_PATH" "$LOCAL_K3S_PATH"; then
    echo "Fehler: SCP-Übertragung fehlgeschlagen"
    exit 1
fi
echo "   -> Datei erfolgreich nach $LOCAL_K3S_PATH geladen."

# ----------------------------------------------------------------------
# 3. KORRIGIEREN DES SERVER-EINTRAGS
# ----------------------------------------------------------------------
echo "3. Korrigiere den Server-Eintrag (127.0.0.1 zu $SERVER_IP)..."
sed -i "s/127.0.0.1/$SERVER_IP/g" "$LOCAL_K3S_PATH"

# ----------------------------------------------------------------------
# 4. MERGEN DER KONFIGURATIONEN
# ----------------------------------------------------------------------
echo "4. Führe die Konfigurationen zusammen..."

mkdir -p "$(dirname "$LOCAL_KUBECONFIG")"
KUBECONFIG="$LOCAL_KUBECONFIG:$LOCAL_K3S_PATH" kubectl config view --flatten > /tmp/merged-kubeconfig
mv /tmp/merged-kubeconfig "$LOCAL_KUBECONFIG"
rm -f "$LOCAL_K3S_PATH"

# ----------------------------------------------------------------------
# 5. ABSCHLUSS & PRÜFUNG
# ----------------------------------------------------------------------
echo "----------------------------------------------------"
echo "Erfolg: Die K3s-Konfiguration wurde gemergt!"
echo "----------------------------------------------------"

echo "Verfügbare Kontexte:"
kubectl config get-contexts | grep -E 'CURRENT|k3s'

NEW_CONTEXT=$(kubectl config get-contexts --no-headers 2>/dev/null | awk '{print $NF}' | grep -E 'k3s' | head -n 1 || true)
if [[ -n "$NEW_CONTEXT" ]]; then
    echo ""
    echo "Um den K3s-Cluster zu verwenden:"
    echo "kubectl config use-context \"$NEW_CONTEXT\""
    echo ""
    kubectl get nodes
fi  