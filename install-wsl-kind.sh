#!/bin/bash
set -e

METALLB_VERSION="0.15.2"

kind create cluster --config=kind-local.yaml

echo "Installing MetalLB (version ${METALLB_VERSION})..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f "${METALLB_MANIFEST_URL}"
echo "MetalLB controller applied."

echo "Applying MetalLB IP address pool configuration..."
kubectl -n metallb-system wait --for=condition=Ready --all pods --timeout 60s
kubectl apply -f wsl-metallb-pool.yaml
kubectl apply -f wsl-metallb-adv.yaml
echo "MetalLB IP pools configured."

# Delete cluster
#kind delete clusters local
