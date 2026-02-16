#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/versions.sh"
source "$SCRIPT_DIR/whelper.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

# --- kubectl (stable-Version von dl.k8s.io) ---
KUBECTL_WANT=$(curl -L -s https://dl.k8s.io/release/stable.txt | sed 's/^v//')
if need_install kubectl "$KUBECTL_WANT"; then
  curl -LO "https://dl.k8s.io/release/v${KUBECTL_WANT}/bin/linux/arm64/kubectl"
  chmod +x ./kubectl
  sudo cp ./kubectl /usr/local/bin
fi

# --- helm ---
if need_install helm "$HELM_VERSION"; then
  wget -q "https://get.helm.sh/helm-v${HELM_VERSION}-linux-arm64.tar.gz"
  tar -zxvf "helm-v${HELM_VERSION}-linux-arm64.tar.gz"
  sudo install -m 555 linux-arm64/helm /usr/local/bin/helm
fi

# --- kind ---
if need_install kind "$KIND_VERSION"; then
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-arm64"
  chmod +x ./kind
  sudo install -m 555 kind /usr/local/bin/kind
fi

# --- istioctl ---
if need_install istioctl "$ISTIO_VERSION"; then
  wget -q "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
  tar -zxvf "istio-${ISTIO_VERSION}-linux-arm64.tar.gz"
  sudo install -m 555 "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl
fi
