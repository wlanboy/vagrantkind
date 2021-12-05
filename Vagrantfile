# -*- mode: ruby -*-
# vi: set ft=ruby :
PUBLIC_IP = "192.168.178.170"
BOX_IMAGE = "generic/ubuntu2004"
BOX_NAME = "kind"
Vagrant.configure("2") do |config|
  config.vm.box = BOX_IMAGE
  config.vm.hostname = BOX_NAME
  config.vm.network :public_network, :dev => 'br0', :type => 'bridge', :ip => PUBLIC_IP
  #config.vm.network "private_network", ip: "192.168.56.70"
  config.vm.disk :disk, size: "50GB", primary: true
  
   config.vm.provider "virtualbox" do |vb|
     vb.gui = false 
     vb.memory = "6024"
     vb.cpus = 4
     vb.name = BOX_NAME
   end
	
   config.vm.provider :libvirt do |domain|
    domain.cpu_mode = 'host-passthrough'
    domain.graphics_type = 'none'
    domain.memory = 6024
    domain.cpus = 4
    domain.features = ['acpi', 'apic', 'pae' ]
    domain.autostart = true
  end

  config.vm.provision "file", source: "istio-settings.yaml", destination: "/home/vagrant/istio-settings.yaml"
  config.vm.provision "file", source: "kind-config.yaml", destination: "/home/vagrant/kind-config.yaml"
  config.vm.provision "file", source: "daemon.json", destination: "/home/vagrant/daemon.json"
  config.vm.provision "file", source: "setup-kind.sh", destination: "setup-kind.sh"

  config.vm.provision "shell", privileged: false, path: "amd64-packages.sh"
  config.vm.provision "shell", privileged: false, path: "amd64-tools.sh"
  config.vm.provision "shell", privileged: false, path: "setup-system.sh"
  
  config.vm.provision "shell", inline: <<-SHELL
    echo "done"
  SHELL
end
