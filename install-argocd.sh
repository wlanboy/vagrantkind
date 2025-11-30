helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace -f values-istio.yaml

cat <<EOF | envsubst | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-cert
  namespace: istio-ingress
spec:
  secretName: argocd-cert-secret
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  commonName: argocd.tp.lan
  isCA: false
  usages:
    - server auth
    - client auth
  dnsNames:
    - argocd.tp.lan
  issuerRef:
    name: local-ca-issuer
    kind: ClusterIssuer
EOF

cat <<EOF | envsubst | kubectl apply -n argocd -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: argocd
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
      credentialName: argocd-cert-secret
    hosts:
    - "argocd.tp.lan"
EOF

kubectl apply -n argocd -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: argocd-vs
  namespace: argocd
spec:
  hosts:
  - "argocd.tp.lan"
  exportTo:
  - "."
  - istio-ingress
  - istio-system
  gateways:
  - argocd/argocd-gateway
  - mesh
  http:
  # Route für das Web-UI (HTTP)
  - match:
    - uri:
        prefix: /argocd
    route:
    - destination:
        host: argocd-server.argocd.svc.cluster.local
        port:
          number: 80
  tcp:
  # Route für gRPC-Web (CLI)
  - match:
    - port: 443
    route:
    - destination:
        host: argocd-server.argocd.svc.cluster.local
        port:
          number: 443
EOF

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
