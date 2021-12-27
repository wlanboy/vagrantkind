#!/bin/bash
set -e
kind create cluster --config=kind-config.yaml
# Calico
curl https://docs.projectcalico.org/manifests/calico.yaml -O
kubectl apply -f calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
# CoreDNS
kubectl scale deployment --replicas 1 coredns --namespace kube-system

# metallb
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/namespace.yaml
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/metallb.yaml
# kubectl get pods --all-namespaces --watch
# docker network inspect -f '{{.IPAM.Config}}' kind
# wget https://kind.sigs.k8s.io/examples/loadbalancer/metallb-configmap.yaml
# kubectl apply -f metallb-configmap.yaml

# Ingress
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Istio
./istioctl manifest apply --set profile=default
./istioctl manifest generate --set profile=default | ./istioctl verify-install -f -
kubectl patch service istio-ingressgateway -n istio-system --patch "$(cat istio-settings.yaml)"

# Delete cluster
#kind delete clusters kindcluster
