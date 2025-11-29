kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd patch deployment argocd-server \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args",
        "value":["/usr/local/bin/argocd-server",
                 "--staticassets","/shared/app",
                 "--redis","argocd-redis:6379",
                 "--insecure",
                 "--basehref","/argocd",
                 "--rootpath","/argocd"]},
       {"op":"add","path":"/spec/template/spec/containers/0/env",
        "value":[{"name":"ARGOCD_MAX_CONCURRENT_LOGIN_REQUESTS_COUNT","value":"0"}]}]'

kubectl rollout status deployment argocd-server -n argocd

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

curl -I https://argocd.tp.lan/argocd
