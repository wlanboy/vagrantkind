#!/bin/bash

# ----------------------------------------------------------------------
# 1. KONFIGURATION
# ----------------------------------------------------------------------
# Ersetzen Sie 'user' durch den SSH-Benutzer auf Ihrem K3s-Server (z.B. pi, ubuntu)
SSH_USER="samuel"
# Standardpfad zur K3s-Config auf dem Server
REMOTE_K3S_PATH="/home/$SSH_USER/.kube/k3s.yaml"
# Temporärer Pfad auf dem lokalen Rechner
LOCAL_K3S_PATH="$HOME/.kube/k3s-remote-temp.yaml"
# Lokale Kubeconfig
LOCAL_KUBECONFIG="$HOME/.kube/config"
# Kube Server
SERVER="gmk"
SERVER_IP=$(ping -c 1 "$SERVER" | head -n 1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n 1)

# ----------------------------------------------------------------------
# 2. ÜBERTRAGEN DER KUBECONFIG VOM SERVER
# ----------------------------------------------------------------------
echo "2. Lade Kubeconfig via SSH/SCP von $SSH_USER@$SERVER..."

# SCP-Befehl zum Herunterladen der Datei
scp "$SSH_USER@$SERVER:$REMOTE_K3S_PATH" "$LOCAL_K3S_PATH"

if [ $? -ne 0 ]; then
    echo "FEHLER: SCP-Übertragung fehlgeschlagen. Prüfen Sie den SSH-Benutzer ($SSH_USER) und die Berechtigungen auf dem Server."
    exit 1
fi

echo "   -> Datei erfolgreich nach $LOCAL_K3S_PATH geladen."

# ----------------------------------------------------------------------
# 3. KORRIGIEREN DES SERVER-EINTRAGS (127.0.0.1 ersetzen)
# ----------------------------------------------------------------------
echo "3. Korrigiere den Server-Eintrag (127.0.0.1:6443 zu $SERVER_IP:6443)..."

# Ersetzt '127.0.0.1' durch die ermittelte lokale IP-Adresse
sed -i "s/127.0.0.1/$SERVER_IP/" "$LOCAL_K3S_PATH"

# ----------------------------------------------------------------------
# 4. MERGEN DER KONFIGURATIONEN
# ----------------------------------------------------------------------
echo "4. Führe die Konfigurationen zusammen und aktualisiere $LOCAL_KUBECONFIG..."

# Erstellt das ~/.kube/ Verzeichnis, falls es nicht existiert
mkdir -p "$(dirname "$LOCAL_KUBECONFIG")"

# Führt die lokale Config und die neue K3s-Config zusammen
KUBECONFIG="$LOCAL_KUBECONFIG:$LOCAL_K3S_PATH" kubectl config view --flatten > /tmp/merged-kubeconfig

# Verschiebt die gemergte Datei an den Standardort
mv /tmp/merged-kubeconfig "$LOCAL_KUBECONFIG"

# Temporäre Datei aufräumen
rm "$LOCAL_K3S_PATH"

# ----------------------------------------------------------------------
# 5. ABSCHLUSS & PRÜFUNG
# ----------------------------------------------------------------------
echo "----------------------------------------------------"
echo "✅ Erfolg: Die K3s-Konfiguration wurde gemergt!"
echo "----------------------------------------------------"

# Zeigt die verfügbaren Kontexte an, um den neuen Namen zu finden
echo "Verfügbare Kontexte (der neue Kontext wurde hinzugefügt):"
kubectl config get-contexts | grep -E 'CURRENT|k3s'

# Optional: Schlägt vor, wie man den Kontext wechselt
NEW_CONTEXT=$(kubectl config get-contexts --no-headers | awk '{print $NF}' | grep -E 'k3s' | head -n 1)
if [ ! -z "$NEW_CONTEXT" ]; then
    echo -e "\nUm Ihren K3s-Cluster zu verwenden, führen Sie aus:"
    echo "kubectl config use-context \"$NEW_CONTEXT\""
    echo "Anschließend prüfen Sie die Knoten mit: kubectl get nodes"
    kubectl get nodes
exit 0  