#!/bin/bash
set -e
kind create cluster --config=kind-config.yaml

# Calico operator
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml -O
kubectl create -f tigera-operator.yaml

# Calico cr
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml -O
kubectl create -f custom-resources.yaml

#kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
# CoreDNS
kubectl scale deployment --replicas 1 coredns --namespace kube-system

# Ingress as an alternative to istio
# curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml -O
# kubectl apply -f deploy.yaml

# Metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
kubectl apply -f metallb-pool.yaml
kubectl apply -f metallb-adv.yaml

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
kubectl create namespace istio-system

helm install istio-base istio/base -n istio-system
helm install istiod istio/istiod -n istio-system --wait

kubectl create namespace istio-ingress
helm install istio-ingress istio/gateway -n istio-ingress --wait
helm install istio-ingressgateway istio/gateway -n istio-ingress

#kubectl patch service istio-ingressgateway -n istio-ingress --patch "$(cat istio-settings.yaml)"

# Demoservice
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl apply -f echo-service-istio.yaml

# Delete cluster
#kind delete clusters k3s
