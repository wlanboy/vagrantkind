#!/bin/bash
set -e
cd ~

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo cp ./kubectl /usr/local/bin

cd /home/vagrant && wget https://get.helm.sh/helm-v3.11.3-linux-amd64.tar.gz
tar -zxvf helm-v3.11.3-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/helm

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin

wget https://github.com/istio/istio/releases/download/1.17.2/istio-1.17.2-linux-amd64.tar.gz
tar -zxvf istio-1.17.2-linux-amd64.tar.gz
sudo cp istio-1.17.2/bin/istioctl /usr/local/bin
