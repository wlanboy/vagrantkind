#!/bin/bash

sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git
    
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
sudo chmod a+r /etc/apt/keyrings/docker.gpg
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io 

update-alternatives --config iptables
sudo usermod -aG docker $USER

wget https://github.com/kubernetes-sigs/kind/releases/download/v0.29.0/kind-linux-amd64
chmod +x kind-linux-amd64 && mv kind-linux-amd64 kind && sudo mv kind /usr/local/bin

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin

wget https://get.helm.sh/helm-v3.17.4-linux-amd64.tar.gz
tar -zxvf helm-v3.17.4-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/helm
