#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage:"
    echo "  $0 /path/to/dpkg-backup-folder"
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

echo "Using backup directory: $BACKUP_DIR"

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

echo
echo "Restore complete."
echo "You may want to reboot now."
