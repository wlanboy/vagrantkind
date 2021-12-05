# vagrantkind
vagrant machine installing docker, kubectrl and kind to run a simple dev kubernetes cluster

# create vm
* vagrant up

# ssh into vm
* vagrant ssh

# create kind kubernetes cluster
* kind create cluster

# create with configuration
* sh setup-kind.sh
* see: https://github.com/wlanboy/vagrantkind/blob/main/setup-kind.sh

# destroy kind kubernetes cluster
* kind delete cluster
* kind delete clusters kindcluster

# example log for cluster creation
```
vagrant@kind:~$ kind create cluster
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.21.1) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind
```

# get basic cluster information
* kubectl cluster-info --context kind-kind
```
vagrant@kind:~$ kubectl cluster-info --context kind-kind
Kubernetes control plane is running at https://127.0.0.1:40239
CoreDNS is running at https://127.0.0.1:40239/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```
* kubectl get nodes
```
vagrant@kind:~$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE     VERSION
kind-control-plane   Ready    control-plane,master   4m10s   v1.21.1
```
* kubectl get pods --all-namespaces
```
vagrant@kind:~$ kubectl get pods --all-namespaces
NAMESPACE            NAME                                         READY   STATUS    RESTARTS   AGE
kube-system          coredns-558bd4d5db-c97b5                     1/1     Running   0          4m
kube-system          coredns-558bd4d5db-vgdhk                     1/1     Running   0          4m
kube-system          etcd-kind-control-plane                      1/1     Running   0          4m9s
kube-system          kindnet-5lg65                                1/1     Running   0          4m1s
kube-system          kube-apiserver-kind-control-plane            1/1     Running   0          4m9s
kube-system          kube-controller-manager-kind-control-plane   1/1     Running   0          4m16s
kube-system          kube-proxy-5gv5b                             1/1     Running   0          4m1s
kube-system          kube-scheduler-kind-control-plane            1/1     Running   0          4m9s
local-path-storage   local-path-provisioner-547f784dff-gbhsc      1/1     Running   0          4m
```
# deploy echo service for testing
* kubectl apply -f echo-pod-service.yml

# start deployen Spring Boot based Service
* see: https://github.com/wlanboy/virtualbox-kubernets/blob/main/deploy-a-service.md
