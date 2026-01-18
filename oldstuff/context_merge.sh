#!/bin/bash
set -e

# Servernamen / Hosts
SERVER1="gmk"
SERVER2="p400"

# Remote-Pfade
REMOTE_PATH="~/.kube/k3s.yaml"

# Lokale Dateinamen
CFG1="config_${SERVER1}"
CFG2="config_${SERVER2}"

echo "📥 Hole kubeconfigs per SCP..."

scp ${SERVER1}:${REMOTE_PATH} ${CFG1}
scp ${SERVER2}:${REMOTE_PATH} ${CFG2}

echo "🔧 Erstelle Backup der bestehenden ~/.kube/config..."
mkdir -p ~/.kube
cp ~/.kube/config ~/.kube/config_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

echo "🔧 Benenne Cluster/User/Context in ${CFG1} um..."
sed -i "s/name: default/name: ${SERVER1}/" ${CFG1}
sed -i "s/cluster: default/cluster: ${SERVER1}/" ${CFG1}
sed -i "s/user: default/user: ${SERVER1}/" ${CFG1}

echo "🔧 Benenne Cluster/User/Context in ${CFG2} um..."
sed -i "s/name: default/name: ${SERVER2}/" ${CFG2}
sed -i "s/cluster: default/cluster: ${SERVER2}/" ${CFG2}
sed -i "s/user: default/user: ${SERVER2}/" ${CFG2}

echo "🔗 Merge kubeconfigs..."
export KUBECONFIG=${CFG1}:${CFG2}
kubectl config view --merge --flatten > ~/.kube/config

echo "🔄 Setze KUBECONFIG zurück..."
unset KUBECONFIG

echo "📋 Verfügbare Kontexte:"
kubectl config use-context ${SERVER1}
kubectl config get-contexts

echo "✅ Fertig! Deine gemergte kubeconfig liegt jetzt in ~/.kube/config"
