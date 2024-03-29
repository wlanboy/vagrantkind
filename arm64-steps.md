# kind + calico + ngxin ingress
see:
* https://www.armbian.com/odroid-c2/#kernels-archive-all
* https://docs.armbian.com/

# generate kind config
```
cat << EOF >> kind-config.yml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kindcluster
networking:
  ipFamily: ipv4
  apiServerAddress: "192.168.178.39"
  apiServerPort: 6443
  podSubnet: "192.168.0.0/16"
  disableDefaultCNI: true
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 9080
    protocol: TCP
  - containerPort: 443
    hostPort: 9443
    protocol: TCP
- role: worker
EOF
```

# create cluster
```
kind create cluster --config kind-config.yml
```

# Calico
```
wget https://github.com/projectcalico/calico/raw/master/manifests/calico.yaml
kubectl apply -f calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
```

# CoreDNS
```
kubectl scale deployment --replicas 1 coredns --namespace kube-system
```

# ingress
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl get pods -n ingress-nginx
```

# deploy echo service
```
kubectl apply -f echo-pod-service.yml
```

# Delete cluster
```
kind delete clusters kindcluster
```
