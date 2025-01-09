#!/usr/bin/env bash

# Context for our app image
APP=brave
BIN="brave"
DEPENDENCIES="alsa-lib cups-libs libxkbcommon libxshmfence mesa nss at-spi2-core \
gtk3 dbus-glib libdrm libxcomposite libxdamage libxrandr libxscrnsaver \
libxtst pango cairo gdk-pixbuf2 libasyncns libpulse libsndfile flac"
BASICSTUFF="binutils gzip curl"

# Grab the latest brave version
BRAVE_VERSION=$(curl -s https://api.github.com/repos/brave/brave-browser/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
echo $BRAVE_VERSION

# CREATE AND ENTER THE APPDIR
mkdir -p "$APP.AppDir"
cd "$APP.AppDir" || exit 1

# Download and extract brave
wget "https://github.com/brave/brave-browser/releases/download/${BRAVE_VERSION}/brave-browser-${BRAVE_VERSION}-linux-amd64.zip"
unzip "brave-browser-${BRAVE_VERSION}-linux-amd64.zip"
rm "brave-browser-${BRAVE_VERSION}-linux-amd64.zip"

# Create AppRun script
cat > AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS}"
export BRAVE_USER_DATA_DIR="${HOME}/.config/brave-appimage"

# Hardware acceleration support
export LIBGL_DRIVERS_PATH="${HERE}/usr/lib/dri"
export LIBVA_DRIVERS_PATH="${HERE}/usr/lib/dri"

exec "${HERE}/brave" "$@"
EOF
chmod +x AppRun

# Create a desktop entry
cat >> brave-browser.desktop << EOF
[Desktop Entry]
Name=Brave
Exec=brave %U
Terminal=false
Icon=brave-browser
Categories=Network;WebBrowser;
EOF


# Download icon
wget https://brave.com/static-assets/images/brave-logo-sans-text.svg brave-browser.png

# Function to handle dependencies
handle_dependencies()
{
  mkdir -p usr/lib usr/bin

  # copy required libraries
  for dep in $DEPENDENCIES; do
    find /usr/lib -name "lib$dep*.so*" -exec cp -P {} usr/lib/ \;
  done

  # copy requried binaries
  for tool in $BASICSTUFF; do
    cp "$(which $tool)" usr/bin 2>/dev/null
  done

  # copy GPU drivers
  mkdir -p usr/lib/dri
  cp /usr/lib/dri/{i965,iris,nouveau,r300,r600,radeonsi}_dri.so usr/lib/dri/ 2>/dev/null
}

handle_dependencies

# function to copy brave binary and its direct dependencies

copy_brave_binary()
{
  mkdir -p usr/bin
  cp brave usr/bin/

  # copy direct dependencies
  lld usr/bin/brave | grep "=>" | awk '{print $3}' | while read -r lib; do
    if [ -f "$lib" ]; then
      mkdir -p "usr/lib/$(dirname "$lib" | sed 's/\/usr\/lib\///')"
      cp -L "$lib" "usr/lib/$(dirname "$lib" | sed 's/\/usr\/lib\///')"
    fi
  done
}

copy_brave_binary

# Build app image
cd ..
wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
chmod +x appimagetool
ARCH=x86_64 ./appimagetool --comp xz "$APP.AppDir" "Brave-${BRAVE_VERSION}-x86_64.AppImage"
EOF
