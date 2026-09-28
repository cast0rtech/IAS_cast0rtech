#!/usr/bin/env bash
# ==============================================================================
# Flash EMA Alpine Diskless OS onto a target SD Card
# Usage: sudo ./flash-sd.sh /dev/sdX
# ==============================================================================

set -euo pipefail

TARGET_DEV="${1:-}"

if [ -z "$TARGET_DEV" ] || [ ! -b "$TARGET_DEV" ]; then
    echo "Usage: sudo $0 /dev/sdX (replace /dev/sdX with your SD card device)"
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)."
    exit 1
fi

echo "WARNING: All data on $TARGET_DEV will be destroyed!"
read -p "Are you sure you want to write to $TARGET_DEV? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo "1. Unmounting existing partitions..."
umount "${TARGET_DEV}"* 2>/dev/null || true

echo "2. Partitioning $TARGET_DEV..."
# Partition 1: FAT32 1GB (Boot, Alpine OS, RAM overlay)
# Partition 2: ext4 Rest (Persistent /data for SQLite)
wipefs -a "$TARGET_DEV"

parted -s "$TARGET_DEV" mklabel msdos
parted -s "$TARGET_DEV" mkpart primary fat32 1MiB 1024MiB
parted -s "$TARGET_DEV" set 1 boot on
parted -s "$TARGET_DEV" mkpart primary ext4 1024MiB 100%

partprobe "$TARGET_DEV"
sleep 2

BOOT_PART="${TARGET_DEV}1"
DATA_PART="${TARGET_DEV}2"
[ -b "${TARGET_DEV}p1" ] && BOOT_PART="${TARGET_DEV}p1"
[ -b "${TARGET_DEV}p2" ] && DATA_PART="${TARGET_DEV}p2"

echo "3. Formatting partitions..."
mkfs.vfat -F 32 -n "EMA_BOOT" "$BOOT_PART"
mkfs.ext4 -F -L "EMA_DATA" "$DATA_PART"

echo "4. Copying EMA Alpine OS files..."
MOUNT_DIR=$(mktemp -d)
mount "$BOOT_PART" "$MOUNT_DIR"

DIST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../dist/alpine-ema-os/bootfs" && pwd)"

if [ ! -d "$DIST_DIR" ]; then
    echo "Dist directory not found. Running build-ema-os.sh first..."
    "$(dirname "${BASH_SOURCE[0]}")/build-ema-os.sh"
fi

cp -r "$DIST_DIR"/* "$MOUNT_DIR/"
sync

umount "$MOUNT_DIR"
rm -rf "$MOUNT_DIR"

echo "====================================================================="
echo "SUCCESS! SD Card successfully formatted and flashed with EMA-OS."
echo "Eject the SD card, insert it into your Raspberry Pi and power on."
echo "====================================================================="
