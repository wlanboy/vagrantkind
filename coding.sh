#!/bin/bash

# Installiere uv
curl -LsSf https://astral.sh/uv/install.sh | bash

# Installiere sdkman
curl -s "https://get.sdkman.io" | bash

# Quellcode für sdkman aktivieren (nötig, um sdkman Befehle zu verwenden)
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Aktualisiere sdkman und installiere Java 25 und maven
sdk update
sdk install java 25-tem
sdk install maven 3.9.9

sudo apt-get update
sudo apt-get install net-tools git nano htop 

wget https://github.com/marktext/marktext/releases/latest/download/marktext-x86_64.AppImage
chmod +x marktext-x86_64.AppImage
