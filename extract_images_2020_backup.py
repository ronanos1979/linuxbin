#!/usr/bin/env python3
"""
Extract all images/videos from iPhone backup 00008030-0001391E0C40802E (16 Aug 2020).
Sources: Camera Roll, iMessage, WhatsApp, Viber, all app domains.

Backup has 33,060 total entries (15,504 dirs + 17,441 files).
Expected extracted image/video count: ~7,000.

Output: /Volumes/Extreme SSD/FirstBackup/iPhone_Images_20200816/
"""

import os
import shutil
import sys
from pathlib import Path
from collections import Counter
from iphone_backup_decrypt import EncryptedBackup

BACKUP_PATH = (
    "/Users/ronanosullivan/Library/Application Support"
    "/MobileSync/Backup/00008030-0001391E0C40802E-20200816-210646"
)
OUTPUT_FOLDER = "/Volumes/Extreme SSD/FirstBackup/iPhone_Images_20200816"
PASSPHRASE = "F@rrel1842"

# Full set of image/video extensions. .thumb excluded (WhatsApp low-res duplicates).
# .jpg_temp = in-progress downloads that are valid JPEGs.
IMAGE_EXTENSIONS = {
    ".jpg", ".jpeg", ".jpg_temp",
    ".png", ".gif",
    ".heic", ".heif",
    ".bmp", ".tiff", ".tif",
    ".webp", ".raw", ".dng",
    ".svg", ".thm",
    ".mov", ".mp4", ".m4v", ".3gp",
}


def check_disk_space(path: str, needed_gb: float = 20.0) -> None:
    total, used, free = shutil.disk_usage(path)
    free_gb = free / (1024 ** 3)
    print(f"Disk space on {path}: {free_gb:.1f} GB free")
    if free_gb < needed_gb:
        print(f"WARNING: Less than {needed_gb} GB free — extraction may fail for large sets.", file=sys.stderr)


def is_image(relative_path: str) -> bool:
    return Path(relative_path).suffix.lower() in IMAGE_EXTENSIONS


def main():
    # --- Disk space checks ---
    output_drive = "/Volumes/Extreme SSD"
    check_disk_space(output_drive, needed_gb=20.0)
    check_disk_space("/System/Volumes/Data", needed_gb=2.0)  # temp manifest DB (~few MB)

    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    print(f"\nBackup : {BACKUP_PATH}")
    print(f"Output : {OUTPUT_FOLDER}")
    print("Decrypting manifest (may take 10-30 seconds)...")

    backup = EncryptedBackup(backup_directory=BACKUP_PATH, passphrase=PASSPHRASE)

    # --- Survey manifest ---
    print("Querying manifest...")
    with backup.manifest_db_cursor() as cur:
        cur.execute(
            "SELECT domain, relativePath, flags FROM Files ORDER BY domain, relativePath"
        )
        all_rows = cur.fetchall()

    regular_files = [(d, rp) for d, rp, f in all_rows if f == 1]
    image_files   = [(d, rp) for d, rp in regular_files if is_image(rp)]
    total_images  = len(image_files)

    print(f"\nTotal backup entries  : {len(all_rows)}")
    print(f"  Regular files       : {len(regular_files)}")
    print(f"  Image/video files   : {total_images}")

    domain_counts = Counter(d for d, _ in image_files)
    print("\nImages by domain:")
    for domain, count in sorted(domain_counts.items(), key=lambda x: -x[1]):
        print(f"  {count:5d}  {domain}")

    if total_images == 0:
        print("\nNo images found — check passphrase or backup path.", file=sys.stderr)
        sys.exit(1)

    # --- Extract ---
    print(f"\nExtracting {total_images} files...")
    extracted = [0]

    def image_filter(*, relative_path, domain, n, total_files, **kwargs):
        keep = is_image(relative_path)
        if keep:
            extracted[0] += 1
            if extracted[0] % 100 == 0:
                pct = extracted[0] / total_images * 100
                print(f"  [{pct:5.1f}%] {extracted[0]}/{total_images}", flush=True)
        return keep

    count = backup.extract_files(
        domain_like="%",
        output_folder=OUTPUT_FOLDER,
        preserve_folders=True,
        domain_subfolders=True,
        filter_callback=image_filter,
    )

    # --- Verify ---
    actual_on_disk = sum(1 for _ in Path(OUTPUT_FOLDER).rglob("*") if _.is_file())
    print(f"\n=== Done ===")
    print(f"API reported extracted : {count}")
    print(f"Files on disk          : {actual_on_disk}")
    print(f"Expected (manifest)    : {total_images}")
    if actual_on_disk < total_images:
        print(f"WARNING: {total_images - actual_on_disk} files may have been skipped or had name collisions.", file=sys.stderr)
    print(f"\nOutput: {OUTPUT_FOLDER}")


if __name__ == "__main__":
    main()
