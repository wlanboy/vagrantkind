#!/bin/bash
set -e

#wget https://github.com/wlanboy/vagrantkind/raw/main/daemon.json
#wget https://github.com/wlanboy/vagrantkind/raw/main/echo-pod-service.yml
#wget https://github.com/wlanboy/vagrantkind/raw/main/istio-settings.yaml
#wget https://github.com/wlanboy/vagrantkind/raw/main/kind-config.yaml

sudo adduser vagrant docker

sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf 

sudo mkdir -p /etc/docker
sudo cp /home/vagrant/daemon.json /etc/docker/daemon.json

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
