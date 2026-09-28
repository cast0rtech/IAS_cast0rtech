#!/usr/bin/env python3
"""
EMA Industrial Alpine OS - Raw .img & .img.zip Image Generator
Creates a bootable, sector-aligned MBR disk image flashable directly with
Balena Etcher and Raspberry Pi Imager.
"""

import os
import shutil
import struct
import sys
import zipfile
from pathlib import Path
from pyfatfs.PyFat import PyFat
from pyfatfs.PyFatFS import PyFatFS

SECTOR_SIZE = 512
MBR_SECTORS = 2048  # 1 MiB alignment
BOOT_PART_SIZE = 512 * 1024 * 1024  # 512 MiB


def make_mbr(start_sector: int, num_sectors: int) -> bytearray:
    """Build a standard MBR sector with Partition 1 set as Active FAT32 LBA."""
    mbr = bytearray(SECTOR_SIZE)
    boot_flag = 0x80  # Active / Bootable
    part_type = 0x0C  # FAT32 with LBA
    start_chs = b"\x00\x20\x21"
    end_chs = b"\xFE\xFF\xFF"

    entry1 = struct.pack(
        "<B3sB3sII",
        boot_flag,
        start_chs,
        part_type,
        end_chs,
        start_sector,
        num_sectors,
    )
    mbr[446:462] = entry1
    mbr[510:512] = b"\x55\xAA"
    return mbr


def copy_tree_to_fatfs(src_dir: Path, fs: PyFatFS):
    """Recursively copy all files and directories into PyFatFS."""
    for root, dirs, files in os.walk(src_dir):
        rel_root = Path(root).relative_to(src_dir)
        fat_dir = rel_root.as_posix()
        if fat_dir != ".":
            fs.makedirs(fat_dir, recreate=True)

        for file_name in files:
            src_file = Path(root) / file_name
            rel_path = (rel_root / file_name).as_posix()
            if rel_path.startswith("./"):
                rel_path = rel_path[2:]

            with open(src_file, "rb") as sf:
                data = sf.read()

            with fs.open(rel_path, "wb") as df:
                df.write(data)


def build_raw_image(bootfs_dir: Path, output_dir: Path):
    output_dir.mkdir(parents=True, exist_ok=True)
    temp_part_file = output_dir / "partition.bin"
    output_img_file = output_dir / "ema-alpine-os.img"
    output_zip_file = output_dir / "ema-alpine-os.img.zip"

    print("=====================================================================")
    print("  EMA Alpine OS - Raw .img Builder (Balena Etcher / Pi Imager)")
    print("=====================================================================")

    # 1. Format raw FAT32 partition
    print(f"[1/4] Pre-allocating and formatting {BOOT_PART_SIZE // (1024*1024)} MiB FAT32 partition...")
    if temp_part_file.exists():
        temp_part_file.unlink()

    with open(temp_part_file, "wb") as f:
        f.truncate(BOOT_PART_SIZE)

    pf = PyFat()
    pf.mkfs(str(temp_part_file), fat_type=PyFat.FAT_TYPE_FAT32, size=BOOT_PART_SIZE, label="EMA_BOOT")
    pf.close()

    # 2. Populate partition with all boot files
    print("[2/4] Copying kernel, overlays, firmware, and EMA application files...")
    fat_fs = PyFatFS(str(temp_part_file))
    copy_tree_to_fatfs(bootfs_dir, fat_fs)
    fat_fs.close()

    # 3. Build MBR and assemble final .img file
    print("[3/4] Assembling sector-aligned MBR disk image...")
    num_sectors = BOOT_PART_SIZE // SECTOR_SIZE
    mbr_sector = make_mbr(MBR_SECTORS, num_sectors)

    if output_img_file.exists():
        output_img_file.unlink()

    with open(output_img_file, "wb") as out_f:
        out_f.write(mbr_sector)
        # Pad remaining sectors of the 1MB alignment with zeroes
        out_f.write(b"\x00" * ((MBR_SECTORS - 1) * SECTOR_SIZE))

        # Stream the FAT32 partition contents
        with open(temp_part_file, "rb") as in_p:
            shutil.copyfileobj(in_p, out_f, length=1024 * 1024)

    if temp_part_file.exists():
        temp_part_file.unlink()

    img_size_mb = output_img_file.stat().st_size / (1024 * 1024)
    print(f"      Disk image generated: {output_img_file} ({img_size_mb:.1f} MiB)")

    # 4. Compress to .img.zip for fast flashing and small download
    print(f"[4/4] Compressing into Balena / Pi Imager ready archive: {output_zip_file}...")
    if output_zip_file.exists():
        output_zip_file.unlink()

    with zipfile.ZipFile(output_zip_file, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(output_img_file, arcname="ema-alpine-os.img")

    zip_size_mb = output_zip_file.stat().st_size / (1024 * 1024)

    print("=====================================================================")
    print("SUCCESS: Ready-to-flash disk image created!")
    print(f"Raw Image:     {output_img_file}")
    print(f"Compressed:    {output_zip_file} ({zip_size_mb:.1f} MiB)")
    print("")
    print("How to flash with Balena Etcher or Raspberry Pi Imager:")
    print("1. Open Balena Etcher or Raspberry Pi Imager.")
    print("2. Choose 'Flash from file' / 'Use Custom' and select:")
    print(f"   {output_zip_file} (or {output_img_file})")
    print("3. Select your MicroSD Card.")
    print("4. Click 'Flash!' and wait for completion.")
    print("=====================================================================")


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent.parent
    bootfs = repo_root / "dist" / "alpine-ema-os" / "bootfs"
    dist = repo_root / "dist" / "alpine-ema-os"

    if not bootfs.exists():
        print(f"Error: Bootfs directory '{bootfs}' not found. Please build the offline bundle first.")
        sys.exit(1)

    build_raw_image(bootfs, dist)
