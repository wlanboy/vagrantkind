#!/bin/bash

CLUSTER_NAME="istio"
KIND_CONFIG_FILE="cluster.yaml"
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml"
METALLB_CONFIG_FILE="metallb-config.yaml"

echo "Erstelle die Kind-Cluster-Konfigurationsdatei (${KIND_CONFIG_FILE})..."
cat <<EOF > "${KIND_CONFIG_FILE}"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
- role: worker
networking:
  kubeProxyMode: iptables
EOF
echo "Kind-Konfiguration gespeichert."

kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG_FILE}"
echo "Kind-Cluster erfolgreich erstellt."

KIND_NET_CIDR=$(docker network inspect kind --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' | head -n 1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}') 

# Überprüfen, ob die CIDR erfolgreich abgerufen wurde
if [ -z "${KIND_NET_CIDR}" ]; then
  echo "Fehler: Konnte die Netzwerk-CIDR des Kind-Clusters nicht ermitteln. Bitte überprüfe deine Docker-Installation oder den Cluster-Status. Beende das Skript."
  exit 1
fi

BASE_IP=$(echo "${KIND_NET_CIDR}" | cut -d'.' -f1-2)
METALLB_IP_RANGE="${BASE_IP}.100.10-${BASE_IP}.100.100"

echo "   Erkannte Kind-Netzwerk-CIDR: ${KIND_NET_CIDR}"
echo "   Vorgeschlagener MetalLB-IP-Bereich: ${METALLB_IP_RANGE}"

echo "Node Labels hinzufügen:"
kubectl label node ${CLUSTER_NAME}-control-plane role=gateway
kubectl label node ${CLUSTER_NAME}-worker role=service

echo "Installiere MetalLB Native vom Manifest: ${METALLB_MANIFEST_URL}..."
kubectl apply -f "${METALLB_MANIFEST_URL}"
echo "   MetalLB-Manifest angewendet."

kubectl -n metallb-system wait --for=condition=Ready --all pods --timeout 60s

echo "Erstelle die MetalLB-Konfiguration mit dem ermittelten IP-Bereich..."
cat <<EOF > "${METALLB_CONFIG_FILE}"
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: docker-pool
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: dockernet
  namespace: metallb-system
spec:
  ipAddressPools:
  - docker-pool
EOF

kubectl apply -f "${METALLB_CONFIG_FILE}"
echo "   MetalLB-Konfiguration (IPAddressPool und L2Advertisement) angewendet."
