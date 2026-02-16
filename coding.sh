#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/versions.sh"
source "$SCRIPT_DIR/whelper.sh"

# --- apt-Pakete ---
APT_PACKAGES=(net-tools git nano htop alacritty curl libfuse2t64)
MISSING_PKGS=()
for pkg in "${APT_PACKAGES[@]}"; do
  if ! is_apt_installed "$pkg"; then
    MISSING_PKGS+=("$pkg")
  fi
done
if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "  apt-Pakete werden installiert: ${MISSING_PKGS[*]}"
  sudo apt-get update
  sudo apt-get install -y "${MISSING_PKGS[@]}"
else
  echo "  Alle apt-Pakete sind bereits installiert -> übersprungen"
fi

# --- uv ---
if ! command -v uv &>/dev/null; then
  echo "  uv ist nicht installiert -> wird installiert"
  curl -LsSf https://astral.sh/uv/install.sh | bash
else
  echo "  uv ist bereits installiert -> übersprungen"
fi

# --- sdkman ---
if [ ! -d "$HOME/.sdkman" ]; then
  echo "  sdkman ist nicht installiert -> wird installiert"
  curl -s "https://get.sdkman.io" | bash
else
  echo "  sdkman ist bereits installiert -> übersprungen"
fi
source "$HOME/.sdkman/bin/sdkman-init.sh"

# --- Java (via sdkman) ---
if sdk_need_install java "$JAVA_VERSION"; then
  sdk install java "$JAVA_VERSION"
fi

# --- Maven (via sdkman) ---
if sdk_need_install maven "$MAVEN_VERSION"; then
  sdk install maven "$MAVEN_VERSION"
fi

# --- VSCode ---
if ! command -v code &>/dev/null; then
  echo "  VSCode ist nicht installiert -> wird installiert"
  wget -q "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -O /tmp/vscode.deb
  sudo apt install -y /tmp/vscode.deb
  rm -f /tmp/vscode.deb
else
  echo "  VSCode ist bereits installiert -> übersprungen"
fi

# Create folders for apps and icons
mkdir -p "$HOME/Applications"
mkdir -p "$HOME/.local/share/icons"

# --- Marktext ---
MARKTEXT_APPIMAGE="$HOME/Applications/marktext-x86_64.AppImage"
if need_file "$MARKTEXT_APPIMAGE" "Marktext"; then
  wget -q https://github.com/marktext/marktext/releases/latest/download/marktext-x86_64.AppImage -O "$MARKTEXT_APPIMAGE"
  chmod +x "$MARKTEXT_APPIMAGE"
fi

DESKTOP_FILE="$HOME/.local/share/applications/marktext.desktop"
if need_file "$DESKTOP_FILE" "Marktext Desktop-Eintrag"; then
  mkdir -p "$(dirname "$DESKTOP_FILE")"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=MarkText
Exec=$MARKTEXT_APPIMAGE --no-sandbox
Icon=marktext
Type=Application
Categories=Utility;TextEditor;
Terminal=false
EOF
  chmod +x "$DESKTOP_FILE"
  gio set "$DESKTOP_FILE" metadata::trusted true
  echo "  Desktop-Datei erstellt unter: $DESKTOP_FILE"
fi

if need_file "$HOME/.local/share/icons/marktext.png" "Marktext Icon"; then
  wget -q "https://github.com/marktext/marktext/blob/develop/resources/icons/icon.png?raw=true" \
       -O "$HOME/.local/share/icons/marktext.png"
fi

# --- LM Studio ---
LMSTUDIO_APPIMAGE="$HOME/Applications/LM-Studio.AppImage"
if need_file "$LMSTUDIO_APPIMAGE" "LM Studio"; then
  wget -q "https://lmstudio.ai/download/latest/linux/x64" -O "$LMSTUDIO_APPIMAGE"
  chmod +x "$LMSTUDIO_APPIMAGE"
fi

DESKTOP_FILE="$HOME/.local/share/applications/lmstudio.desktop"
if need_file "$DESKTOP_FILE" "LM Studio Desktop-Eintrag"; then
  mkdir -p "$(dirname "$DESKTOP_FILE")"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=LM Studio
Exec=$LMSTUDIO_APPIMAGE --no-sandbox
Icon=lmstudio
Type=Application
Categories=Utility;Development;
Terminal=false
EOF
  chmod +x "$DESKTOP_FILE"
  gio set "$DESKTOP_FILE" metadata::trusted true
  echo "  Desktop-Datei erstellt unter: $DESKTOP_FILE"
fi

if need_file "$HOME/.local/share/icons/lmstudio.png" "LM Studio Icon"; then
  wget -q "https://lmstudio.ai/assets/android-chrome-512x512.png" \
       -O "$HOME/.local/share/icons/lmstudio.png"
fi

# Update Desktop Database
update-desktop-database ~/.local/share/applications/
