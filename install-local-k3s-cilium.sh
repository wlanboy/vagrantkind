#!/bin/bash
#set -euo pipefail

# See: https://github.com/cilium/cilium/releases
CILIUM_VERSION="1.18.6"

# Prüfen ob als root ausgeführt wird (sollte nicht)
if [[ $EUID -eq 0 ]]; then
    echo "Bitte nicht als root ausführen"
    exit 1
fi

# IP ermitteln mit Fehlerprüfung
LOKALE_IP=$(ip a s | grep "inet " | grep "192.168.178." | awk '{print $2}' | cut -d/ -f1)
if [[ -z "$LOKALE_IP" ]]; then
    echo "Fehler: Keine IP im Bereich 192.168.178.x gefunden"
    exit 1
fi
echo "IP: $LOKALE_IP"

# .kube Verzeichnis erstellen falls nicht vorhanden
mkdir -p ~/.kube

# K3s Installation ohne Flannel (Cilium übernimmt CNI)
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
K3S_KUBECONFIG_MODE="644" \
INSTALL_K3S_CHANNEL=stable \
INSTALL_K3S_EXEC="--disable=traefik --flannel-backend=none --disable-network-policy --cluster-cidr=10.42.0.0/16 --service-cidr=10.43.0.0/16 --node-external-ip=$LOKALE_IP" \
/tmp/k3s-install.sh

# Kubeconfig kopieren
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s.yaml
sudo chown "$USER":"$USER" ~/.kube/k3s.yaml
cp ~/.kube/k3s.yaml ~/.kube/config
sed -i "s/127.0.0.1/$LOKALE_IP/g" ~/.kube/k3s.yaml
sed -i "s/127.0.0.1/$LOKALE_IP/g" ~/.kube/config

# Node-Token sichern
sudo cp /var/lib/rancher/k3s/server/node-token ~/.kube/node-token
sudo chown "$USER":"$USER" ~/.kube/node-token

# Helm installieren falls nicht vorhanden
if ! command -v helm &> /dev/null; then
    echo "Installiere Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Cilium Helm Repo hinzufügen
helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
helm repo update

#socketLB.hostNamespaceOnly=true	
#Socket LB nur im Host-Namespace, nicht in Pod-Namespaces - damit Istio Sidecars den Traffic korrekt abfangen koennen

# Cilium installieren mit L2 Announcements und LB-IPAM
echo "Installing Cilium (version ${CILIUM_VERSION})..."
helm install cilium cilium/cilium --version "${CILIUM_VERSION}" \
    --namespace kube-system \
    --set operator.replicas=1 \
    --set ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16" \
    --set l2announcements.enabled=true \
    --set l2announcements.leaseDuration="3s" \
    --set l2announcements.leaseRenewDeadline="1s" \
    --set l2announcements.leaseRetryPeriod="500ms" \
    --set externalIPs.enabled=true \
    --set devices="{eth0,enp+}" \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost="${LOKALE_IP}" \
    --set k8sServicePort=6443 \
    --set socketLB.hostNamespaceOnly=true \
    --set bpf.monitorAggregation=none

echo "Warte auf Cilium Pods..."
kubectl -n kube-system wait --for=condition=Ready --all pods -l app.kubernetes.io/part-of=cilium --timeout=300s

# Warten bis Node bereit ist
echo "Warte auf K3s Node..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Cilium IP Pool und L2 Advertisement erstellen
echo "Konfiguriere Cilium LB-IPAM..."
kubectl apply -f - <<EOF
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: first-pool
spec:
  blocks:
  - start: "192.168.178.230"
    stop: "192.168.178.240"
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: l2-policy
spec:
  interfaces:
  - ^eth[0-9]+
  - ^enp.*
  externalIPs: true
  loadBalancerIPs: true
EOF

echo "Cilium mit L2 Load Balancing konfiguriert."

# Delete cluster
#sudo /usr/local/bin/k3s-uninstall.sh
