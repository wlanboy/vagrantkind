#!/bin/bash
set -e
cd ~

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
chmod +x ./kubectl
sudo cp ./kubectl /usr/local/bin

# see https://github.com/helm/helm/releases
HELM_VERSION="3.19.4"
# see https://github.com/kubernetes-sigs/kind/releases/
KIND_VERSION="0.31.0"
# see https://github.com/istio/istio/releases/
ISTIO_VERSION="1.28.2"
# see https://github.com/derailed/k9s/releases
K9S_VERSION="0.50.16"
#see https://github.com/argoproj/argo-cd/releases
ARGOCD_VERSION="v3.2.3"

wget "https://get.helm.sh/helm-v${HELM_VERSION}-linux-arm64.tar.gz"
tar -zxvf "helm-v${HELM_VERSION}-linux-arm64.tar.gz"
sudo cp linux-arm64/helm /usr/local/bin/helm

curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-arm64"
chmod +x ./kind
sudo cp ./kind /usr/local/bin

wget "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
tar -zxvf "istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
sudo cp "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin

curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-arm64
sudo install -m 555 argocd-linux-arm64 /usr/local/bin/argocd
rm argocd-linux-arm64

wget "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_arm64.tar.gz"
tar -zxvf k9s_Linux_arm64.tar.gz
sudo cp ./k9s /usr/local/bin
