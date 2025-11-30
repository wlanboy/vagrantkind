#!/bin/bash

kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install \
cert-manager jetstack/cert-manager \
--namespace cert-manager \
--set crds.enabled=true

kubectl create secret tls my-local-ca-secret \
--namespace cert-manager \
--cert=/local-ca/ca.pem \
--key=/local-ca/ca.key

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: local-ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: my-local-ca-secret
EOF

echo "Überprüfe den Status der cert-manager-Pods..."
kubectl get pods -n cert-manager -o wide
echo "Überprüfe die cert-manager-Installation..."
kubectl get clusterissuers