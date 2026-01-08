sudo apt update
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid

helm repo add longhorn https://charts.longhorn.io
helm repo update

kubectl create namespace longhorn-system

helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --set defaultSettings.defaultReplicaCount=1 \
  --set persistence.defaultClassReplicaCount=1

cat <<EOF | envsubst | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: longhorn-cert-secret
  namespace: istio-ingress
spec:
  secretName: longhorn-cert-secret
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  commonName: longhorn.gmk.lan
  isCA: false
  usages:
    - server auth
    - client auth
  dnsNames:
    - longhorn.gmk.lan
  issuerRef:
    name: local-ca-issuer
    kind: ClusterIssuer
EOF

cat <<EOF | envsubst | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: longhorn-gateway
  namespace: longhorn-system
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
      credentialName: longhorn-cert-secret
    hosts:
    - "longhorn.gmk.lan"
EOF

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: longhorn-vs
  namespace: longhorn-system
spec:
  hosts:
  - "longhorn.gmk.lan"
  exportTo:
  - "."
  - istio-ingress
  - istio-system
  gateways:
  - istio-ingress/longhorn-gateway
  - mesh
spec:
  exportTo:
    - .
    - istio-ingress
    - istio-system
  gateways:
    - longhorn-gateway
    - mesh
  hosts:
    - longhorn.gmk.lan
  http:
    - route:
        - destination:
            host: longhorn-frontend
            port:
              number: 80
EOF
