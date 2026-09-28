#!/usr/bin/env bash
# ==============================================================================
# EMA Appliance - Automated Raspberry Pi OS Image Builder
# Creates an uncompressed / compressed bootable .img for Raspberry Pi
# ==============================================================================

set -euo pipefail

BASE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images"
OUTPUT_DIR="./build"
IMAGE_NAME="ema-appliance-raspios-lite-arm64.img"

echo "=== EMA Raspberry Pi OS Image Generator ==="
echo "Note: This script prepares an unattended appliance image."

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$OUTPUT_DIR/base.img.xz" ]; then
    echo "Downloading latest official 64-bit Raspberry Pi OS Lite image..."
    curl -L -o "$OUTPUT_DIR/base.img.xz" \
        "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz" || {
        echo "Direct download URL requires update; please download the latest official image from raspberrypi.com."
        exit 1
    }
fi

echo "Extracting base image..."
xz -dk -f "$OUTPUT_DIR/base.img.xz"
BASE_IMG=$(find "$OUTPUT_DIR" -name "*.img" ! -name "$IMAGE_NAME" | head -n 1)

cp "$BASE_IMG" "$OUTPUT_DIR/$IMAGE_NAME"

echo "Injecting cloud-init and bootstrap configuration into boot partition..."
# Using mtools or loop mounting to inject user-data and network-config
if command -v kpartx >/dev/null 2>&1; then
    LOOP_DEV=$(kpartx -av "$OUTPUT_DIR/$IMAGE_NAME" | head -n 1 | awk '{print $3}' | sed 's/p1$//')
    mkdir -p /mnt/rpi-boot
    mount "/dev/mapper/${LOOP_DEV}p1" /mnt/rpi-boot
    cp ./rpi/cloud-init/user-data /mnt/rpi-boot/user-data
    cp ./rpi/cloud-init/network-config /mnt/rpi-boot/network-config
    touch /mnt/rpi-boot/ssh
    umount /mnt/rpi-boot
    kpartx -d "$OUTPUT_DIR/$IMAGE_NAME"
    echo "Image successfully built: $OUTPUT_DIR/$IMAGE_NAME"
else
    echo "kpartx not found. You can flash the base image using Raspberry Pi Imager and apply rpi/cloud-init/user-data."
fi
