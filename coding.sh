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

# Install VSCode
wget https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64 -O vscode.deb
sudo apt-get update
sudo apt-get install net-tools git nano htop 
sudo apt install vscode.deb

# Create folders for apps and icons
mkdir -p ~/Applications 
mkdir $HOME/.share/icons

# Install Marktext
wget https://github.com/marktext/marktext/releases/latest/download/marktext-x86_64.AppImage
mv marktext-x86_64.AppImage ~/Applications/
chmod +x ~/Applications/marktext-x86_64.AppImage

# Zielpfad für die .desktop-Datei
DESKTOP_FILE="$HOME/.local/share/applications/marktext.desktop"
# Pfad zur AppImage-Datei (anpassbar)
APPIMAGE_PATH="$HOME/Applications/marktext-x86_64.AppImage"
# Datei erstellen
mkdir -p "$(dirname "$DESKTOP_FILE")"
touch "$DESKTOP_FILE"
# Inhalt einfügen
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=MarkText
Exec="$APPIMAGE_PATH" --no-sandbox
Icon=marktext
Type=Application
Categories=Utility;TextEditor;
Terminal=false
EOF

chmod +x $DESKTOP_FILE
echo "Desktop-Datei erstellt unter: $DESKTOP_FILE"

wget "https://github.com/marktext/marktext/blob/develop/resources/icons/icon.png?raw=true" \
     -O ~/.local/share/icons/marktext.png

wget https://lmstudio.ai/download/latest/linux/x64
mv LM-Studio-0.4.2-2-x64.AppImage ~/Applications/
chmod +x ~/Applications/LM-Studio-0.4.2-2-x64.AppImage

# Zielpfad für die .desktop-Datei
DESKTOP_FILE="$HOME/.local/share/applications/lmstudio.desktop"
# Pfad zur AppImage-Datei (anpassbar)
APPIMAGE_PATH="$HOME/Applications/LM-Studio-0.4.2-2-x64.AppImage"
# Datei erstellen
mkdir -p "$(dirname "$DESKTOP_FILE")"
touch "$DESKTOP_FILE"
# Inhalt einfügen
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=LM Studio
Exec="$APPIMAGE_PATH" --no-sandbox
Icon=lmstudio
Type=Application
Categories=Utility;Development;
Terminal=false
EOF

chmod +x $DESKTOP_FILE
echo "Desktop-Datei erstellt unter: $DESKTOP_FILE"

wget "https://lmstudio.ai/assets/android-chrome-512x512.png" \
     -O ~/.local/share/icons/lmstudio.png

# Update Desktop Database
update-desktop-database ~/.local/share/applications/
