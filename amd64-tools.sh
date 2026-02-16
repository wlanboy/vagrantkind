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
  curl -LO "https://dl.k8s.io/release/v${KUBECTL_WANT}/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo cp ./kubectl /usr/local/bin
fi

# --- helm ---
if need_install helm "$HELM_VERSION"; then
  wget -q "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz"
  tar -zxvf "helm-v${HELM_VERSION}-linux-amd64.tar.gz"
  sudo install -m 555 linux-amd64/helm /usr/local/bin/helm
fi

# --- kind ---
if need_install kind "$KIND_VERSION"; then
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64"
  chmod +x ./kind
  sudo install -m 555 kind /usr/local/bin/kind
fi

# --- istioctl ---
if need_install istioctl "$ISTIO_VERSION"; then
  wget -q "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz"
  tar -zxvf "istio-${ISTIO_VERSION}-linux-amd64.tar.gz"
  sudo install -m 555 "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl
fi

# --- k9s ---
if need_install k9s "$K9S_VERSION"; then
  wget -q "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
  tar -zxvf k9s_Linux_amd64.tar.gz
  sudo install -m 555 k9s /usr/local/bin/k9s
fi

# --- argocd ---
ARGOCD_WANT="${ARGOCD_VERSION#v}"
if need_install argocd "$ARGOCD_WANT"; then
  curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
fi

# --- hey (kein Versionscheck möglich, nur Existenz) ---
if need_install hey ""; then
  wget -q https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
  sudo install -m 555 hey_linux_amd64 /usr/local/bin/hey
fi

# --- mirrord ---
if ! command -v mirrord &>/dev/null; then
  echo "  mirrord ist nicht installiert -> wird installiert"
  curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash
else
  echo "  mirrord ist bereits installiert -> übersprungen"
fi
