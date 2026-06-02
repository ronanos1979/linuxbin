#!/bin/bash
set -euo pipefail

OUTPUT_DIR="$HOME/local/bin"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d)"
BACKUP_NAME="dpkg-package-backup-${TIMESTAMP}.tar.gz"
BACKUP_PATH="${OUTPUT_DIR}/${BACKUP_NAME}"

echo "Creating package backup..."
echo "Temporary work dir: $WORK_DIR"

mkdir -p "$WORK_DIR/package-backup"

# Packages explicitly installed by the user
apt-mark showmanual | sort > "$WORK_DIR/package-backup/apt-manual-packages.txt"

# Full dpkg selections, useful for reference
dpkg --get-selections > "$WORK_DIR/package-backup/dpkg-selections.txt"

# APT sources
cp -a /etc/apt/sources.list "$WORK_DIR/package-backup/" 2>/dev/null || true
cp -a /etc/apt/sources.list.d "$WORK_DIR/package-backup/" 2>/dev/null || true

# Flatpak apps, if installed
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application | sort > "$WORK_DIR/package-backup/flatpak-apps.txt"
fi

# Snap packages, if installed
if command -v snap >/dev/null 2>&1; then
    snap list | awk 'NR>1 {print $1}' | sort > "$WORK_DIR/package-backup/snap-packages.txt"
fi

# Useful system info
{
    echo "Created: $(date)"
    echo
    lsb_release -a 2>/dev/null || true
    echo
    uname -a
} > "$WORK_DIR/package-backup/system-info.txt"

# Create one tarball
tar -czf "$BACKUP_PATH" -C "$WORK_DIR" package-backup

rm -rf "$WORK_DIR"

echo
echo "Backup complete:"
echo "$BACKUP_PATH"
echo
echo "To add it to git:"
echo "  cd $OUTPUT_DIR"
echo "  git add dpkg-backup.sh dpkg-restore.sh $BACKUP_NAME"
echo "  git commit -m \"Update package backup\""
