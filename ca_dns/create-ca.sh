#!/bin/bash

# === Lokale CA-Dateien ===
mkdir -p ~/local-ca
cd ~/local-ca

openssl genrsa -out ca.key 4096

openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -out ca.pem -subj "/C=DE/ST=Germany/L=LAN/O=Homelab CA/CN=Homelab Test Root CA"

sudo cp ca.pem /usr/local/share/ca-certificates/ca-test-lan.crt
sudo update-ca-certificates
