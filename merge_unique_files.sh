[200~#!/bin/bash

# merge_unique_files_fast.sh
#
# Move or copy files from SOURCE into DEST, preserving folder structure.
# Skip a source file if the same filename already exists anywhere under DEST.
#
# Usage:
#   ./merge_unique_files_fast.sh --dry-run SOURCE_DIR DEST_DIR
#   ./merge_unique_files_fast.sh --copy    SOURCE_DIR DEST_DIR
#   ./merge_unique_files_fast.sh --move    SOURCE_DIR DEST_DIR

set -u

MODE="dry-run"

if [ "$#" -lt 3 ]; then
  echo "Usage:"
  echo "  $0 --dry-run SOURCE_DIR DEST_DIR"
  echo "  $0 --copy    SOURCE_DIR DEST_DIR"
  echo "  $0 --move    SOURCE_DIR DEST_DIR"
  exit 1
fi

case "$1" in
  --dry-run) MODE="dry-run" ;;
  --copy) MODE="copy" ;;
  --move) MODE="move" ;;
  *)
    echo "Invalid mode: $1"
    echo "Use --dry-run, --copy, or --move"
    exit 1
    ;;
esac

abs_path() {
  local path="$1"
  if [ -d "$path" ]; then
    cd "$path" >/dev/null 2>&1 && pwd -P
  else
    local dir
    local base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    cd "$dir" >/dev/null 2>&1 && echo "$(pwd -P)/$base"
  fi
}

SOURCE_DIR="$(abs_path "$2")"
DEST_DIR="$(abs_path "$3")"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
  echo "Destination directory does not exist, creating it: $DEST_DIR"
  mkdir -p "$DEST_DIR"
fi

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_DIR="$DEST_DIR/_merge_logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/merge_unique_log_$TIMESTAMP.csv"
SKIPPED_FILE="$LOG_DIR/merge_unique_skipped_$TIMESTAMP.csv"

echo "source_path,destination_path,action,reason" > "$LOG_FILE"
echo "source_path,existing_destination_path,reason" > "$SKIPPED_FILE"

echo "Mode: $MODE"
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "Log: $LOG_FILE"
echo "Skipped: $SKIPPED_FILE"
echo ""

DEST_INDEX="$(mktemp)"
SOURCE_LIST="$(mktemp)"

echo "Building destination filename index..."

find "$DEST_DIR" -type f ! -path "$SOURCE_DIR/*" -print0 | while IFS= read -r -d '' dest_file; do
  printf "%s\t%s\n" "$(basename "$dest_file")" "$dest_file"
done > "$DEST_INDEX"

echo "Building source file list..."

find "$SOURCE_DIR" -type f -print0 > "$SOURCE_LIST"

echo "Processing files..."
echo ""

file_exists_in_dest_by_name() {
  local filename="$1"
  awk -F '\t' -v f="$filename" '$1 == f { found=1; exit } END { exit !found }' "$DEST_INDEX"
}

find_existing_dest_path() {
  local filename="$1"
  awk -F '\t' -v f="$filename" '$1 == f { print $2; exit }' "$DEST_INDEX"
}

add_to_dest_index() {
  local filename="$1"
  local path="$2"
  printf "%s\t%s\n" "$filename" "$path" >> "$DEST_INDEX"
}

while IFS= read -r -d '' source_file; do
  filename="$(basename "$source_file")"

  if file_exists_in_dest_by_name "$filename"; then
    existing_path="$(find_existing_dest_path "$filename")"

    echo "[SKIP] $source_file"
    echo "       Existing in destination: $existing_path"

    echo "\"$source_file\",\"$existing_path\",\"filename already exists in destination tree\"" >> "$SKIPPED_FILE"
    echo "\"$source_file\",\"\",\"skipped\",\"filename already exists in destination tree\"" >> "$LOG_FILE"
    continue
  fi

  relative_path="${source_file#$SOURCE_DIR/}"
  target_path="$DEST_DIR/$relative_path"
  target_dir="$(dirname "$target_path")"

  if [ "$MODE" = "dry-run" ]; then
    echo "[DRY RUN] $source_file"
    echo "          -> $target_path"
    echo "\"$source_file\",\"$target_path\",\"dry-run\",\"would transfer\"" >> "$LOG_FILE"
    add_to_dest_index "$filename" "$target_path"
    continue
  fi

  mkdir -p "$target_dir"

  if [ "$MODE" = "copy" ]; then
    cp -p "$source_file" "$target_path"
    echo "[COPIED] $source_file -> $target_path"
    echo "\"$source_file\",\"$target_path\",\"copied\",\"new filename\"" >> "$LOG_FILE"
  elif [ "$MODE" = "move" ]; then
    mv "$source_file" "$target_path"
    echo "[MOVED] $source_file -> $target_path"
    echo "\"$source_file\",\"$target_path\",\"moved\",\"new filename\"" >> "$LOG_FILE"
  fi

  add_to_dest_index "$filename" "$target_path"

done < "$SOURCE_LIST"

rm -f "$DEST_INDEX" "$SOURCE_LIST"

echo ""
echo "Done."
echo "Log: $LOG_FILE"
echo "Skipped: $SKIPPED_FILE"
