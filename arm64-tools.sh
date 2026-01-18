#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/versions.sh"

cd ~

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
chmod +x ./kubectl
sudo cp ./kubectl /usr/local/bin

wget "https://get.helm.sh/helm-v${HELM_VERSION}-linux-arm64.tar.gz"
tar -zxvf "helm-v${HELM_VERSION}-linux-arm64.tar.gz"
sudo install -m 555 linux-arm64/helm /usr/local/bin/helm
rm "helm-v${HELM_VERSION}-linux-arm64.tar.gz"
rm -Rf linux-arm64

curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-arm64"
chmod +x ./kind
sudo install -m 555 kind /usr/local/bin/kind
rm kind

wget "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
tar -zxvf "istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
sudo install -m 555 "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl
rm "istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
rm -Rf "istio-${ISTIO_VERSION}"
