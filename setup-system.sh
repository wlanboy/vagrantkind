#!/bin/bash
set -e
sudo adduser vagrant docker

sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf 

sudo mkdir -p /etc/docker
sudo cp /home/vagrant/daemon.json /etc/docker/daemon.json

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab