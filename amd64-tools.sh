#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/versions.sh"

cd ~

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo cp ./kubectl /usr/local/bin

wget "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz"
tar -zxvf "helm-v${HELM_VERSION}-linux-amd64.tar.gz"
sudo install -m 555 linux-amd64/helm /usr/local/bin/helm
rm "helm-v${HELM_VERSION}-linux-amd64.tar.gz"
rm -Rf linux-amd64

curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64"
chmod +x ./kind
sudo install -m 555 kind /usr/local/bin/kind
rm kind

wget "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz"
tar -zxvf "istio-${ISTIO_VERSION}-linux-amd64.tar.gz"
sudo install -m 555 "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl
rm "istio-${ISTIO_VERSION}-linux-amd64.tar.gz"
rm -Rf "istio-${ISTIO_VERSION}"

wget "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
tar -zxvf k9s_Linux_amd64.tar.gz
sudo install -m 555 k9s /usr/local/bin/k9s
rm k9s_Linux_amd64.tar.gz
rm -f k9s LICENSE README.md

curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
sudo install -m 555 hey_linux_amd64 /usr/local/bin/hey
rm hey_linux_amd64

curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash
