#!/bin/bash

# rename_photos_current_folder.sh
#
# Renames photo/video files in the CURRENT directory only.
# Does not move files.
# Does not process folders.
#
# Naming format:
#   YYYYMMDD_HHMMSS_originalname.ext
#
# If the target already exists:
#   *_identical.ext
#   *_duplicate_diff_size.ext
#
# Usage:
#   ./rename_photos_current_folder.sh --dry-run
#   ./rename_photos_current_folder.sh --rename

set -u

MODE="dry-run"

if [ "$#" -lt 1 ]; then
  echo "Usage:"
  echo "  $0 --dry-run"
  echo "  $0 --rename"
  exit 1
fi

case "$1" in
  --dry-run)
    MODE="dry-run"
    ;;
  --rename)
    MODE="rename"
    ;;
  *)
    echo "Invalid mode: $1"
    echo "Use --dry-run or --rename"
    exit 1
    ;;
esac

command -v exiftool >/dev/null 2>&1 || {
  echo "ExifTool is required but not installed."
  echo "Install it with: brew install exiftool"
  exit 1
}

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="./rename_log_$TIMESTAMP.csv"
SKIPPED_FILE="./rename_skipped_$TIMESTAMP.csv"

echo "original_name,new_name,metadata_date,action,comparison" > "$LOG_FILE"
echo "original_name,reason" > "$SKIPPED_FILE"

get_metadata_date() {
  local file="$1"

  exiftool -s3 -d "%Y-%m-%d %H:%M:%S" \
    -DateTimeOriginal \
    -SubSecDateTimeOriginal \
    -CreateDate \
    -MediaCreateDate \
    -TrackCreateDate \
    -CreationDate \
    "$file" 2>/dev/null | \
    awk 'NF { print; exit }'
}

sanitize_name() {
  local name="$1"

  echo "$name" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9._-]/_/g' | \
    sed 's/__*/_/g' | \
    sed 's/^_//' | \
    sed 's/_$//'
}

file_hash() {
  local file="$1"
  shasum -a 256 "$file" | awk '{print $1}'
}

file_size_bytes() {
  local file="$1"
  stat -f "%z" "$file" 2>/dev/null
}

technical_signature() {
  local file="$1"

  local width
  local height
  local duration
  local size

  width="$(exiftool -s3 -ImageWidth "$file" 2>/dev/null | head -1)"
  height="$(exiftool -s3 -ImageHeight "$file" 2>/dev/null | head -1)"
  duration="$(exiftool -s3 -Duration "$file" 2>/dev/null | head -1)"
  size="$(file_size_bytes "$file")"

  duration="$(echo "$duration" | tr -d ' ')"

  echo "width=$width;height=$height;duration=$duration;size=$size"
}

compare_existing_file() {
  local source_file="$1"
  local existing_file="$2"

  local source_hash
  local existing_hash
  local source_sig
  local existing_sig

  source_hash="$(file_hash "$source_file")"
  existing_hash="$(file_hash "$existing_file")"

  if [ "$source_hash" = "$existing_hash" ]; then
    echo "identical"
    return
  fi

  source_sig="$(technical_signature "$source_file")"
  existing_sig="$(technical_signature "$existing_file")"

  if [ "$source_sig" = "$existing_sig" ]; then
    echo "identical"
    return
  fi

  echo "duplicate_diff_size"
}

add_suffix_before_extension() {
  local filename="$1"
  local suffix="$2"

  local ext
  local stem

  if [[ "$filename" == *.* ]]; then
    ext="${filename##*.}"
    stem="${filename%.*}"
    echo "${stem}_${suffix}.${ext}"
  else
    echo "${filename}_${suffix}"
  fi
}

make_unique_name() {
  local filename="$1"

  if [ ! -e "$filename" ]; then
    echo "$filename"
    return
  fi

  local ext
  local stem
  local counter
  local candidate

  if [[ "$filename" == *.* ]]; then
    ext="${filename##*.}"
    stem="${filename%.*}"
  else
    ext=""
    stem="$filename"
  fi

  counter=2

  while true; do
    if [ -n "$ext" ]; then
      candidate="${stem}_${counter}.${ext}"
    else
      candidate="${stem}_${counter}"
    fi

    if [ ! -e "$candidate" ]; then
      echo "$candidate"
      return
    fi

    counter=$((counter + 1))
  done
}

resolve_new_name() {
  local source_file="$1"
  local target_name="$2"

  # If the source file already has the desired name, do nothing.
  if [ "$source_file" = "./$target_name" ] || [ "$source_file" = "$target_name" ]; then
    echo "$target_name|already_named"
    return
  fi

  if [ ! -e "$target_name" ]; then
    echo "$target_name|new"
    return
  fi

  local comparison
  local suffixed_name
  local final_name

  comparison="$(compare_existing_file "$source_file" "$target_name")"

  if [ "$comparison" = "identical" ]; then
    suffixed_name="$(add_suffix_before_extension "$target_name" "identical")"
  else
    suffixed_name="$(add_suffix_before_extension "$target_name" "duplicate_diff_size")"
  fi

  final_name="$(make_unique_name "$suffixed_name")"

  echo "$final_name|$comparison"
}

process_file() {
  local file="$1"

  local metadata_date
  metadata_date="$(get_metadata_date "$file")"

  if [ -z "$metadata_date" ]; then
    echo "\"$file\",\"No usable metadata date found\"" >> "$SKIPPED_FILE"
    return
  fi

  if ! echo "$metadata_date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'; then
    echo "\"$file\",\"Invalid metadata date: $metadata_date\"" >> "$SKIPPED_FILE"
    return
  fi

  local year
  local month
  local day
  local hour
  local minute
  local second
  local datetime_prefix

  year="$(echo "$metadata_date" | cut -c1-4)"
  month="$(echo "$metadata_date" | cut -c6-7)"
  day="$(echo "$metadata_date" | cut -c9-10)"
  hour="$(echo "$metadata_date" | cut -c12-13)"
  minute="$(echo "$metadata_date" | cut -c15-16)"
  second="$(echo "$metadata_date" | cut -c18-19)"

  datetime_prefix="${year}${month}${day}_${hour}${minute}${second}"

  local filename
  local ext
  local stem
  local clean_stem
  local target_name
  local resolved
  local final_name
  local comparison

  filename="$(basename "$file")"
  ext="${filename##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  stem="${filename%.*}"

  clean_stem="$(sanitize_name "$stem")"

  if [ -z "$clean_stem" ]; then
    clean_stem="file"
  fi

  target_name="${datetime_prefix}_${clean_stem}.${ext}"

  resolved="$(resolve_new_name "$file" "$target_name")"
  final_name="${resolved%|*}"
  comparison="${resolved##*|}"

  if [ "$comparison" = "already_named" ]; then
    echo "[SKIP] Already named: $filename"
    echo "\"$filename\",\"$final_name\",\"$metadata_date\",\"already_named\",\"$comparison\"" >> "$LOG_FILE"
    return
  fi

  if [ "$MODE" = "dry-run" ]; then
    echo "[DRY RUN] $filename"
    echo "          -> $final_name"
    echo "          comparison: $comparison"
    echo "\"$filename\",\"$final_name\",\"$metadata_date\",\"dry-run\",\"$comparison\"" >> "$LOG_FILE"
    return
  fi

  mv -n "$filename" "$final_name"
  echo "[RENAMED] $filename -> $final_name [$comparison]"
  echo "\"$filename\",\"$final_name\",\"$metadata_date\",\"renamed\",\"$comparison\"" >> "$LOG_FILE"
}

echo "Mode: $MODE"
echo "Folder: $(pwd)"
echo "Log file: $LOG_FILE"
echo "Skipped file: $SKIPPED_FILE"
echo ""

find . -maxdepth 1 -type f \( \
  -iname "*.jpg"  -o \
  -iname "*.jpeg" -o \
  -iname "*.heic" -o \
  -iname "*.heif" -o \
  -iname "*.png"  -o \
  -iname "*.gif"  -o \
  -iname "*.tif"  -o \
  -iname "*.tiff" -o \
  -iname "*.dng"  -o \
  -iname "*.raw"  -o \
  -iname "*.cr2"  -o \
  -iname "*.cr3"  -o \
  -iname "*.nef"  -o \
  -iname "*.arw"  -o \
  -iname "*.raf"  -o \
  -iname "*.rw2"  -o \
  -iname "*.mov"  -o \
  -iname "*.mp4"  -o \
  -iname "*.m4v"  -o \
  -iname "*.avi"  -o \
  -iname "*.mkv"  -o \
  -iname "*.3gp" \
\) -print0 | while IFS= read -r -d '' file; do
  process_file "$file"
done

echo ""
echo "Done."
echo "Log: $LOG_FILE"
echo "Skipped: $SKIPPED_FILE"
