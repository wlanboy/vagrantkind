#!/bin/bash
set -euo pipefail

helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

kubectl create namespace argo-workflows --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argo-events --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace argo-workflows istio-injection=enabled --overwrite
kubectl label namespace argo-events istio-injection=enabled --overwrite

if ! helm status argo-workflows --namespace argo-workflows &>/dev/null; then
  helm install argo-workflows argo/argo-workflows --namespace argo-workflows
fi

if ! helm status argo-events --namespace argo-events &>/dev/null; then
  helm install argo-events argo/argo-events --namespace argo-events
fi

read -rsp "Docker Password: " DOCKER_PASSWORD
echo

kubectl delete secret regcred -n argo-workflows --ignore-not-found
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="${DOCKER_USERNAME}" \
  --docker-password="${DOCKER_PASSWORD}" \
  --docker-email="${DOCKER_EMAIL}" \
  -n argo-workflows

echo "Erstelle Argo Workflows Certificate..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argo-workflows-cert-secret
  namespace: istio-ingress
spec:
  secretName: argo-workflows-cert-secret
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  commonName: argocdworkflow.gmk.lan
  isCA: false
  usages:
    - server auth
    - client auth
  dnsNames:
    - argocdworkflow.gmk.lan
  issuerRef:
    name: local-ca-issuer
    kind: ClusterIssuer
EOF

echo "Erstelle Istio Gateway..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: argo-workflows-gateway
  namespace: istio-ingress
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: argo-workflows-cert-secret
    hosts:
    - "argocdworkflow.gmk.lan"
EOF

echo "Erstelle VirtualService..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: argo-workflows-vs
  namespace: argo-workflows
spec:
  hosts:
  - "argocdworkflow.gmk.lan"
  exportTo:
  - "."
  - istio-ingress
  - istio-system
  gateways:
  - istio-ingress/argo-workflows-gateway
  - mesh
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: argo-workflows-server.argo-workflows.svc.cluster.local
        port:
          number: 2746
EOF

echo "Erstelle Workflow-Controller RBAC..."
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-controller-role
  namespace: argo-workflows
rules:
  - apiGroups: [""]
    resources: [secrets]
    verbs: [get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-controller-role-binding
  namespace: argo-workflows
subjects:
  - kind: ServiceAccount
    name: argo-workflows-workflow-controller
    namespace: argo-workflows
roleRef:
  kind: Role
  name: workflow-controller-role
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Erstelle ServiceAccount, Role und RoleBinding..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: workflow-sa
  namespace: argo-workflows
imagePullSecrets:
  - name: regcred
secrets:
  - name: regcred
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-role
  namespace: argo-workflows
rules:
  - apiGroups: [""]
    resources: [pods, pods/log]
    verbs: [get, list, watch, create, delete, patch]
  - apiGroups: [""]
    resources: [configmaps]
    verbs: [get, list, watch]
  - apiGroups: [argoproj.io]
    resources: [workflows, workflowtemplates, cronworkflows, workfloweventbindings, eventsources, sensors, workflowtaskresults]
    verbs: [get, list, watch, create, update, patch, delete]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: workflow-cluster-role
rules:
  - apiGroups: [argoproj.io]
    resources: [clusterworkflowtemplates]
    verbs: [get, list, watch]
  - apiGroups: [argoproj.io]
    resources: [workflows, workflowtemplates, cronworkflows, workfloweventbindings, eventsources, sensors, workflowtaskresults]
    verbs: [get, list, watch]
  - apiGroups: [""]
    resources: [pods, pods/log]
    verbs: [get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: workflow-cluster-role-binding
subjects:
  - kind: ServiceAccount
    name: workflow-sa
    namespace: argo-workflows
roleRef:
  kind: ClusterRole
  name: workflow-cluster-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-role-binding
  namespace: argo-workflows
subjects:
  - kind: ServiceAccount
    name: workflow-sa
    namespace: argo-workflows
roleRef:
  kind: Role
  name: workflow-role
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Erstelle RBAC fuer workflow-sa im argocd Namespace..."
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-sa-role
  namespace: argocd
rules:
  - apiGroups: [argoproj.io]
    resources: [eventsources, sensors]
    verbs: [get, list, watch, create, update, patch, delete]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-sa-role-binding
  namespace: argocd
subjects:
  - kind: ServiceAccount
    name: workflow-sa
    namespace: argo-workflows
roleRef:
  kind: Role
  name: workflow-sa-role
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Erstelle ServiceAccount Token..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: workflow-sa-token
  namespace: argo-workflows
  annotations:
    kubernetes.io/service-account.name: workflow-sa
type: kubernetes.io/service-account-token
EOF

echo ""
echo "Argo Workflows Installation abgeschlossen."
echo "Erreichbar unter: https://argocdworkflow.gmk.lan"
echo ""
echo -n "Argo Workflows Token: Bearer "
kubectl get secret workflow-sa-token -n argo-workflows -o jsonpath='{.data.token}' | base64 -d
echo ""
