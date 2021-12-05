#!/bin/bash
set -e
kind create cluster --config=kind-config.yaml
# Calico
curl https://docs.projectcalico.org/manifests/calico.yaml -O
kubectl apply -f calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
# CoreDNS
kubectl scale deployment --replicas 1 coredns --namespace kube-system

# Istio
#./istioctl manifest apply --set profile=default
#./istioctl manifest generate --set profile=default | ./istioctl verify-install -f -
#kubectl patch service istio-ingressgateway -n istio-system --patch "$(cat istio-settings.yaml)"

# Delete cluster
#kind delete clusters kindcluster