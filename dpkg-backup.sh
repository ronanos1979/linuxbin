#!/bin/bash
set -e

BACKUP_DIR="$HOME/dpkg-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Creating package backup in: $BACKUP_DIR"

# Packages explicitly installed by you via apt
apt-mark showmanual | sort > "$BACKUP_DIR/apt-manual-packages.txt"

# All dpkg packages currently installed
dpkg --get-selections > "$BACKUP_DIR/dpkg-selections.txt"

# Flatpak apps, if Flatpak is installed
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application > "$BACKUP_DIR/flatpak-apps.txt"
fi

# Snap packages, if Snap is installed
if command -v snap >/dev/null 2>&1; then
    snap list | awk 'NR>1 {print $1}' > "$BACKUP_DIR/snap-packages.txt"
fi

# APT repositories/sources
cp -a /etc/apt/sources.list "$BACKUP_DIR/" 2>/dev/null || true
cp -a /etc/apt/sources.list.d "$BACKUP_DIR/" 2>/dev/null || true

# Useful system info
lsb_release -a > "$BACKUP_DIR/system-info.txt" 2>/dev/null || true
uname -a >> "$BACKUP_DIR/system-info.txt"

echo
echo "Backup complete."
echo "Files created:"
ls -lh "$BACKUP_DIR"
echo
echo "Main package list:"
echo "$BACKUP_DIR/apt-manual-packages.txt"
