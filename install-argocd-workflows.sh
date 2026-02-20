#!/bin/bash
set -euo pipefail

helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

if ! helm status argo-workflows --namespace argocd &>/dev/null; then
  helm install argo-workflows argo/argo-workflows --namespace argocd
fi

read -rsp "Docker Password: " DOCKER_PASSWORD
echo

kubectl create secret docker-registry regcred \
  --docker-server=index.docker.io \
  --docker-username="${DOCKER_USERNAME}" \
  --docker-password="${DOCKER_PASSWORD}" \
  --docker-email="${DOCKER_EMAIL}" \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: workflow-sa
  namespace: argocd
imagePullSecrets:
  - name: regcred
secrets:
  - name: regcred
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-role
  namespace: argocd
rules:
  - apiGroups: [""]
    resources: [pods, pods/log]
    verbs: [get, list, watch, create, delete, patch]
  - apiGroups: [""]
    resources: [configmaps]
    verbs: [get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-role-binding
  namespace: argocd
subjects:
  - kind: ServiceAccount
    name: workflow-sa
roleRef:
  kind: Role
  name: workflow-role
  apiGroup: rbac.authorization.k8s.io
EOF
