kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

cat <<EOF | envsubst | kubectl apply -n argocd -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-cert
  namespace: argocd
spec:
  secretName: argocd-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "$(curl -s https://api.ipify.org)"
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
      credentialName: argocd-tls
    hosts:
    - "$(curl -s https://api.ipify.org)"
EOF

kubectl apply -n argocd -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: argocd-vs
  namespace: argocd
spec:
  hosts:
  - "$(curl -s https://api.ipify.org)"
  gateways:
  - argocd/argocd-gateway
  http:
  - route:
    - destination:
        host: argocd-server
        port:
          number: 443
EOF

