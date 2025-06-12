#!/bin/bash
set -e
cd ~

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
chmod +x ./kubectl
sudo cp ./kubectl /usr/local/bin

HELM_VERSION="3.18.2"
KIND_VERSION="0.29.0"
ISTIO_VERSION="1.26.1"

wget "https://get.helm.sh/helm-v${HELM_VERSION}-linux-arm64.tar.gz"
tar -zxvf "helm-v${HELM_VERSION}-linux-arm64.tar.gz"
sudo cp linux-arm64/helm /usr/local/bin/helm

curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-arm64"
chmod +x ./kind
sudo cp ./kind /usr/local/bin

wget "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
tar -zxvf "istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
sudo cp "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin
