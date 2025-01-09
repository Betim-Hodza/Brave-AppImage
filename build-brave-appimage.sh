#!/usr/bin/env bash

# Context for our app image
APP=brave
BIN="brave"
DEPENDENCIES="alsa-lib cups-libs libxkbcommon libxshmfence mesa nss at-spi2-core \
gtk3 dbus-glib libdrm libxcomposite libxdamage libxrandr libxscrnsaver \
libxtst pango cairo gdk-pixbuf2 libasyncns libpulse libsndfile flac "
BASICSTUFF="binutils gzip curl appstreamcli lld"
COMPILERS="base-devel"

# Grab the latest brave version
BRAVE_VERSION=$(curl -s https://api.github.com/repos/brave/brave-browser/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//')

# CREATE AND ENTER THE APPDIR
mkdir -p "$APP.AppDir"
cd "$APP.AppDir" || exit 1
# example of working link https://github.com/brave/brave-browser/releases/download/v1.74.46/brave-browser-1.74.46-linux-amd64.zip
# Download and extract brave
wget "https://github.com/brave/brave-browser/releases/download/v${BRAVE_VERSION}/brave-browser-${BRAVE_VERSION}-linux-amd64.zip"
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
cat >> "$APP".desktop << EOF
[Desktop Entry]
Type=Application
Name=$(echo "$APP" | tr a-z A-Z)
Exec=$BIN
Terminal=false
Icon=brave
Categories=Network;WebBrowser;
EOF

# Create appdata.xml file
mkdir -p usr/share/metainfo
cat > usr/share/metainfo/brave.appdata.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>brave.desktop</id>
  <metadata_license>CC0-1.0</metadata_license>
  <name>Brave</name>
  <summary>Secure, Fast & Private Web Browser</summary>
  <description>
    <p>Brave is a fast, secure, and privacy-focused web browser.</p>
  </description>
  <launchable type="desktop-id">brave.desktop</launchable>
  <url type="homepage">https://brave.com/</url>
</component>
EOF

# Download icon
wget https://cdn.icon-icons.com/icons2/2622/PNG/512/browser_brave_icon_157736.png
mv browser_brave_icon_157736.png brave.png

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
  ldd usr/bin/brave | grep "=>" | awk '{print $3}' | while read -r lib; do
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
ARCH=x86_64 ./appimagetool --comp zstd "$APP.AppDir" "Brave-${BRAVE_VERSION}-x86_64.AppImage"

