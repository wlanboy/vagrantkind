#!/bin/bash
set -e

CALICO_VERSION="3.30.1"
METALLB_VERSION="0.15.2"

kind create cluster --config=kind-config.yaml

echo "Installing Calico CNI (version ${CALICO_VERSION})..."
CALICO_OPERATOR_URL="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml"
CALICO_CR_URL="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml"

echo "Downloading Calico operator manifest..."
curl "${CALICO_OPERATOR_URL}" -O tigera-operator.yaml
kubectl create -f tigera-operator.yaml
echo "Waiting for Calico operator to be ready ..."
kubectl wait --for=condition=Available deployment/calico-tigera-operator -n calico-operator --timeout=30s

echo "Downloading Calico custom resources manifest..."
curl "${CALICO_CR_URL}" -O custom-resources.yaml
kubectl create -f custom-resources.yaml
echo "Waiting for Calico node and controllers to be ready ..."
kubectl wait --for=condition=Available deployment/calico-kube-controllers -n kube-system --timeout=30s
kubectl wait --for=condition=Available daemonset/calico-node -n kube-system --timeout=30s
echo "Calico CNI installed and ready."

# Optional: Uncomment the following line if you encounter specific networking issues with Calico.
# kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

# CoreDNS
kubectl scale deployment --replicas 1 coredns --namespace kube-system

echo "Installing MetalLB (version ${METALLB_VERSION})..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"
echo "MetalLB controller applied."

echo "Applying MetalLB IP address pool configuration..."
kubectl apply -f metallb-pool.yaml
kubectl apply -f metallb-adv.yaml
echo "MetalLB IP pools configured."

# Ingress as an alternative to istio
# curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml -O
# kubectl apply -f deploy.yaml

echo "Adding Istio Helm repository and updating..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
echo "Istio Helm repository added and updated."

echo "Creating 'istio-system' namespace if it doesn't exist..."
kubectl get ns istio-system &>/dev/null || kubectl create namespace istio-system
echo "'istio-system' namespace ensured."

echo "Installing Istio Base components into 'istio-system'..."
helm install istio-base istio/base -n istio-system --wait
echo "Istio Base installed."

echo "Installing Istiod (Istio Control Plane) into 'istio-system'..."
helm install istiod istio/istiod -n istio-system --wait
echo "Istiod installed and ready."

echo "Creating 'istio-ingress' namespace if it doesn't exist..."
kubectl get ns istio-ingress &>/dev/null || kubectl create namespace istio-ingress
echo "'istio-ingress' namespace ensured."

echo "Installing Istio Ingress Gateway into 'istio-ingress'..."
helm install istio-ingressgateway istio/gateway -n istio-ingress --wait
echo "Istio Ingress Gateway installed."

# Optional: Uncomment the following line to patch the Istio ingress gateway service.
# kubectl patch service istio-ingressgateway -n istio-ingress --patch "$(cat istio-settings.yaml)"

# --- Demo Service Deployment ---
echo "Deploying demo service..."
echo "Creating 'demo' namespace if it doesn't exist..."
kubectl get ns demo &>/dev/null || kubectl create namespace demo
echo "'demo' namespace ensured."

echo "Enabling Istio injection for the 'demo' namespace..."
kubectl label namespace demo istio-injection=enabled --overwrite
echo "Istio injection enabled for 'demo' namespace."

echo "Applying 'echo-service-istio.yaml' to deploy the demo service..."
# Ensure 'echo-service-istio.yaml' is present in the same directory.
kubectl apply -f echo-service-istio.yaml
echo "Demo service deployment initiated."

# test
#curl -H "Host: demo.com" http://172.18.250.10/

# Delete cluster
#kind delete clusters k3s
