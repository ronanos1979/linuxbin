#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "  $0 /path/to/dpkg-package-backup.tar.gz"
    exit 1
fi

BACKUP_TARBALL="$1"

if [ ! -f "$BACKUP_TARBALL" ]; then
    echo "Backup tarball not found: $BACKUP_TARBALL"
    exit 1
fi

WORK_DIR="$(mktemp -d)"

echo "Extracting backup:"
echo "$BACKUP_TARBALL"

tar -xzf "$BACKUP_TARBALL" -C "$WORK_DIR"

BACKUP_DIR="$WORK_DIR/package-backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Invalid backup archive: package-backup folder not found."
    rm -rf "$WORK_DIR"
    exit 1
fi

echo
echo "System info from backup:"
cat "$BACKUP_DIR/system-info.txt" 2>/dev/null || true
echo

read -p "Proceed with apt package restore? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    rm -rf "$WORK_DIR"
    exit 0
fi

sudo apt update

if [ -f "$BACKUP_DIR/apt-manual-packages.txt" ]; then
    echo "Restoring manually installed apt packages..."
    xargs -a "$BACKUP_DIR/apt-manual-packages.txt" sudo apt install -y
else
    echo "No apt-manual-packages.txt found."
fi

if [ -f "$BACKUP_DIR/flatpak-apps.txt" ] && command -v flatpak >/dev/null 2>&1; then
    echo "Restoring Flatpak apps..."
    xargs -a "$BACKUP_DIR/flatpak-apps.txt" -r flatpak install -y flathub
fi

if [ -f "$BACKUP_DIR/snap-packages.txt" ] && command -v snap >/dev/null 2>&1; then
    echo "Restoring Snap packages..."
    xargs -a "$BACKUP_DIR/snap-packages.txt" -r sudo snap install
fi

rm -rf "$WORK_DIR"

echo
echo "Restore complete."
echo "You may want to reboot."
