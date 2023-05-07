#!/bin/bash
set -e
kind create cluster --config=kind-config.yaml

# Calico operator
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml -O
kubectl create -f tigera-operator.yaml

# Calico cr
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml -O
kubectl create -f custom-resources.yaml

kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
# CoreDNS
kubectl scale deployment --replicas 1 coredns --namespace kube-system

# Ingress as an alternative to istio
# curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml -O
# kubectl apply -f deploy.yaml

# Istio
./istioctl manifest apply --set profile=default
#./istioctl manifest generate --set profile=default | ./istioctl verify-install -f --skip-confirmation -
kubectl patch service istio-ingressgateway -n istio-system --patch "$(cat istio-settings.yaml)"

# Delete cluster
#kind delete clusters kindcluster
