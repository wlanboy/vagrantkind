curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_CHANNEL=stable INSTALL_K3S_EXEC="--disable=traefik --disable=servicelb" sh -
mkdir ~/.kube
sudo cp -i /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

istioctl install --set profile=default -y

kubectl get svc istio-ingressgateway -n istio-system
