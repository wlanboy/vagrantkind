#!/bin/bash

# Installiere uv
curl -LsSf https://astral.sh/uv/install.sh | bash

# Installiere sdkman
curl -s "https://get.sdkman.io" | bash

# Quellcode für sdkman aktivieren (nötig, um sdkman Befehle zu verwenden)
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Aktualisiere sdkman und installiere Java 25
sdk update
sdk install java 25-tem

# Aktualisiere sdkman und installiere Maven 3.9.9
sdk update
sdk install maven 3.9.9
