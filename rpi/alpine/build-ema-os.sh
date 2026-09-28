#!/usr/bin/env bash
# ==============================================================================
# EMA Appliance - Automated Alpine Linux Diskless (RAM-Only) OS Generator
# Architecture: aarch64 (Raspberry Pi 3B+, 4, 5, CM4, CM5)
# Characteristics: 100% Run from RAM, 3s Boot, Immune to Power Loss Corruption
# ==============================================================================

set -euo pipefail

ALPINE_VERSION="3.20.3"
ALPINE_TAR="alpine-rpi-${ALPINE_VERSION}-aarch64.tar.gz"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/aarch64/${ALPINE_TAR}"

OUTPUT_DIR="$(pwd)/dist/alpine-ema-os"
APKOVL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/apkovl" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Building EMA Industrial Diskless OS (Alpine Linux RAM-Engine) ==="

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/cache"

# 1. Download official Alpine Linux Raspberry Pi tarball
if [ ! -f "$OUTPUT_DIR/cache/$ALPINE_TAR" ]; then
    echo "Downloading official Alpine Linux for Raspberry Pi (v${ALPINE_VERSION} aarch64)..."
    curl -fsSL -o "$OUTPUT_DIR/cache/$ALPINE_TAR" "$ALPINE_URL"
fi

# 2. Extract base Alpine distribution into target directory
TARGET_BOOT="$OUTPUT_DIR/bootfs"
rm -rf "$TARGET_BOOT"
mkdir -p "$TARGET_BOOT"

echo "Extracting Alpine base system..."
tar -xzf "$OUTPUT_DIR/cache/$ALPINE_TAR" -C "$TARGET_BOOT"

# 3. Create the EMA Appliance Overlay (ema-gateway.apkovl.tar.gz)
echo "Generating custom apkovl overlay..."
APKOVL_TMP=$(mktemp -d)

# Copy overlay template files
cp -r "$APKOVL_DIR"/* "$APKOVL_TMP/"

# Make scripts executable
chmod 755 "$APKOVL_TMP/etc/init.d/"*
chmod 755 "$APKOVL_TMP/etc/local.d/"*

# Configure OpenRC runlevels
mkdir -p "$APKOVL_TMP/etc/runlevels/default"
mkdir -p "$APKOVL_TMP/etc/runlevels/boot"
mkdir -p "$APKOVL_TMP/etc/runlevels/sysinit"

ln -sf /etc/init.d/chronyd "$APKOVL_TMP/etc/runlevels/default/chronyd"
ln -sf /etc/init.d/sshd "$APKOVL_TMP/etc/runlevels/default/sshd"
ln -sf /etc/init.d/nginx "$APKOVL_TMP/etc/runlevels/default/nginx"
ln -sf /etc/init.d/local "$APKOVL_TMP/etc/runlevels/default/local"
ln -sf /etc/init.d/ema-backend "$APKOVL_TMP/etc/runlevels/default/ema-backend"
ln -sf /etc/init.d/ema-watchdog "$APKOVL_TMP/etc/runlevels/default/ema-watchdog"

# Embed the EMA application codebase
mkdir -p "$APKOVL_TMP/opt/ema"
cp -r "$REPO_ROOT/backend" "$APKOVL_TMP/opt/ema/"
cp -r "$REPO_ROOT/frontend" "$APKOVL_TMP/opt/ema/"
cp -r "$REPO_ROOT/rpi" "$APKOVL_TMP/opt/ema/"
cp "$REPO_ROOT/alarme.csv" "$APKOVL_TMP/opt/ema/"
[ -f "$REPO_ROOT/.env" ] && cp "$REPO_ROOT/.env" "$APKOVL_TMP/opt/ema/" || cp "$REPO_ROOT/.env.example" "$APKOVL_TMP/opt/ema/.env"

# Embed offline Python wheels for 100% air-gapped installation
if [ -d "$(dirname "${BASH_SOURCE[0]}")/wheels" ]; then
    mkdir -p "$APKOVL_TMP/opt/ema/vendor/wheels"
    cp "$(dirname "${BASH_SOURCE[0]}")/wheels"/*.whl "$APKOVL_TMP/opt/ema/vendor/wheels/" 2>/dev/null || true
fi

# Compress overlay into hostname.apkovl.tar.gz
HOSTNAME="ema-gateway"
echo "$HOSTNAME" > "$APKOVL_TMP/etc/hostname"
tar -czf "$TARGET_BOOT/${HOSTNAME}.apkovl.tar.gz" -C "$APKOVL_TMP" etc opt
rm -rf "$APKOVL_TMP"

# 4. Configure Raspberry Pi firmware settings (usercfg.txt)
cat << 'EOF' > "$TARGET_BOOT/usercfg.txt"
# Hardware Watchdog
dtparam=watchdog=on

# Disable bluetooth and audio to conserve RAM & power
dtoverlay=disable-bt
dtparam=audio=off

# HDMI Hotplug (enable for industrial panels)
hdmi_force_hotplug=1
EOF

# 5. Pack into bootable ZIP release
RELEASE_ZIP="$OUTPUT_DIR/ema-alpine-os-aarch64.zip"
echo "Creating ready-to-flash release archive: $RELEASE_ZIP..."
(cd "$TARGET_BOOT" && zip -r -q "$RELEASE_ZIP" .)

echo "====================================================================="
echo "SUCCESS: EMA Industrial Alpine Diskless OS created!"
echo "Distribution directory: $TARGET_BOOT"
echo "Flasheable ZIP:         $RELEASE_ZIP"
echo "====================================================================="
echo "How to install on SD Card:"
echo "1. Format your SD Card with FAT32."
echo "2. Extract the contents of $RELEASE_ZIP directly onto the SD Card."
echo "3. Insert the SD Card into the Raspberry Pi and power on."
echo "   It will boot in 3 seconds directly into RAM!"
echo "====================================================================="
