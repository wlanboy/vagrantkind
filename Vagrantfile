# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"
  config.vm.hostname = "kind"
  config.vm.network "private_network", ip: "192.168.56.60"
  config.vm.disk :disk, size: "50GB", primary: true

   config.vm.provider "virtualbox" do |vb|
     vb.gui = false # keep it in background without console window
     vb.memory = "4098"
     vb.cpus = 4
     vb.name = "kind"
   end

  config.vm.provision "shell", inline: <<-SHELL
	set -e
	export DEBIAN_FRONTEND=noninteractive
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
	echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update

  sudo apt-get install -y nano htop apt-transport-https ca-certificates curl gnupg2 software-properties-common lsb-release wget net-tools
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  sudo apt-get install -y kubelet kubeadm kubectl

	curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
	chmod +x ./kind
	sudo mv ./kind /usr/bin
  
	sudo adduser vagrant docker
  SHELL
end
