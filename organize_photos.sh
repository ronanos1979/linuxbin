#!/bin/bash

# organize_photos.sh
#
# Organize photos/videos by metadata date.
#
# Behavior:
#   - Copies by default when --copy is used.
#   - Moves only when --move is used.
#   - Leaves files untouched if no usable metadata date is found.
#   - If destination file already exists:
#       * exact same hash OR same technical signature -> _identical
#       * different resolution/duration/file size -> _duplicate_diff_size
#
# Optional:
#   --split-media
#       Puts photos under DEST_DIR/Photos/...
#       Puts videos under DEST_DIR/Videos/...
#
# Usage:
#   ./organize_photos.sh --dry-run SOURCE_DIR DEST_DIR
#   ./organize_photos.sh --copy    SOURCE_DIR DEST_DIR
#   ./organize_photos.sh --move    SOURCE_DIR DEST_DIR
#
#   ./organize_photos.sh --dry-run SOURCE_DIR DEST_DIR --split-media
#   ./organize_photos.sh --copy    SOURCE_DIR DEST_DIR --split-media
#   ./organize_photos.sh --move    SOURCE_DIR DEST_DIR --split-media

set -u

MODE="dry-run"
SPLIT_MEDIA="false"

if [ "$#" -lt 3 ]; then
  echo "Usage:"
  echo "  $0 --dry-run SOURCE_DIR DEST_DIR [--split-media]"
  echo "  $0 --copy    SOURCE_DIR DEST_DIR [--split-media]"
  echo "  $0 --move    SOURCE_DIR DEST_DIR [--split-media]"
  exit 1
fi

case "$1" in
  --dry-run)
    MODE="dry-run"
    ;;
  --copy)
    MODE="copy"
    ;;
  --move)
    MODE="move"
    ;;
  *)
    echo "Invalid mode: $1"
    echo "Use --dry-run, --copy, or --move"
    exit 1
    ;;
esac

SOURCE_DIR="$2"
DEST_DIR="$3"

if [ "$#" -ge 4 ]; then
  case "$4" in
    --split-media)
      SPLIT_MEDIA="true"
      ;;
    *)
      echo "Invalid optional argument: $4"
      echo "Use --split-media or omit it."
      exit 1
      ;;
  esac
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$DEST_DIR"

LOG_DIR="$DEST_DIR/_organizer_logs"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="$LOG_DIR/organize_log_$TIMESTAMP.csv"
SKIPPED_FILE="$LOG_DIR/skipped_no_metadata_$TIMESTAMP.csv"

echo "original_path,new_path,metadata_date,media_type,action,comparison" > "$LOG_FILE"
echo "original_path,reason" > "$SKIPPED_FILE"

command -v exiftool >/dev/null 2>&1 || {
  echo "ExifTool is required but not installed."
  echo "Install it with: brew install exiftool"
  exit 1
}

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
  local path="$1"
  local suffix="$2"

  local dir
  local base
  local ext
  local stem

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [[ "$base" == *.* ]]; then
    ext="${base##*.}"
    stem="${base%.*}"
    echo "$dir/${stem}_${suffix}.${ext}"
  else
    echo "$dir/${base}_${suffix}"
  fi
}

make_unique_suffix_path() {
  local path="$1"

  if [ ! -e "$path" ]; then
    echo "$path"
    return
  fi

  local dir
  local base
  local ext
  local stem
  local counter
  local candidate

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [[ "$base" == *.* ]]; then
    ext="${base##*.}"
    stem="${base%.*}"
  else
    ext=""
    stem="$base"
  fi

  counter=2

  while true; do
    if [ -n "$ext" ]; then
      candidate="$dir/${stem}_${counter}.${ext}"
    else
      candidate="$dir/${stem}_${counter}"
    fi

    if [ ! -e "$candidate" ]; then
      echo "$candidate"
      return
    fi

    counter=$((counter + 1))
  done
}

resolve_destination_path() {
  local source_file="$1"
  local target_path="$2"

  if [ ! -e "$target_path" ]; then
    echo "$target_path|new"
    return
  fi

  local comparison
  local suffixed_path
  local final_path

  comparison="$(compare_existing_file "$source_file" "$target_path")"

  if [ "$comparison" = "identical" ]; then
    suffixed_path="$(add_suffix_before_extension "$target_path" "identical")"
  else
    suffixed_path="$(add_suffix_before_extension "$target_path" "duplicate_diff_size")"
  fi

  final_path="$(make_unique_suffix_path "$suffixed_path")"

  echo "$final_path|$comparison"
}

get_media_type() {
  local file="$1"
  local filename
  local ext

  filename="$(basename "$file")"
  ext="${filename##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"

  case "$ext" in
    jpg|jpeg|heic|heif|png|gif|tif|tiff|dng|raw|cr2|cr3|nef|arw|raf|rw2|webp|bmp)
      echo "Photos"
      ;;
    mov|mp4|m4v|avi|mkv|3gp|3g2|mts|m2ts|mpg|mpeg|wmv)
      echo "Videos"
      ;;
    *)
      echo "Other"
      ;;
  esac
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
  local month_name
  local date_folder
  local datetime_prefix

  year="$(echo "$metadata_date" | cut -c1-4)"
  month="$(echo "$metadata_date" | cut -c6-7)"
  day="$(echo "$metadata_date" | cut -c9-10)"
  hour="$(echo "$metadata_date" | cut -c12-13)"
  minute="$(echo "$metadata_date" | cut -c15-16)"
  second="$(echo "$metadata_date" | cut -c18-19)"

  case "$month" in
    01) month_name="January" ;;
    02) month_name="February" ;;
    03) month_name="March" ;;
    04) month_name="April" ;;
    05) month_name="May" ;;
    06) month_name="June" ;;
    07) month_name="July" ;;
    08) month_name="August" ;;
    09) month_name="September" ;;
    10) month_name="October" ;;
    11) month_name="November" ;;
    12) month_name="December" ;;
    *)
      echo "\"$file\",\"Invalid month: $month\"" >> "$SKIPPED_FILE"
      return
      ;;
  esac

  date_folder="${year}-${month}-${day}"
  datetime_prefix="${year}${month}${day}_${hour}${minute}${second}"

  local filename
  local ext
  local stem
  local clean_stem
  local media_type
  local base_dest_dir
  local target_dir
  local target_file
  local target_path
  local resolved
  local final_path
  local comparison

  filename="$(basename "$file")"
  ext="${filename##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  stem="${filename%.*}"

  clean_stem="$(sanitize_name "$stem")"

  if [ -z "$clean_stem" ]; then
    clean_stem="file"
  fi

  media_type="$(get_media_type "$file")"

  if [ "$SPLIT_MEDIA" = "true" ]; then
    base_dest_dir="$DEST_DIR/$media_type"
  else
    base_dest_dir="$DEST_DIR"
  fi

  target_dir="$base_dest_dir/$year/$month-$month_name/$date_folder"
  target_file="${datetime_prefix}_${clean_stem}.${ext}"
  target_path="$target_dir/$target_file"

  mkdir -p "$target_dir"

  resolved="$(resolve_destination_path "$file" "$target_path")"
  final_path="${resolved%|*}"
  comparison="${resolved##*|}"

  if [ "$MODE" = "dry-run" ]; then
    echo "[DRY RUN] $file"
    echo "          -> $final_path"
    echo "          media type: $media_type"
    echo "          comparison: $comparison"
    echo "\"$file\",\"$final_path\",\"$metadata_date\",\"$media_type\",\"dry-run\",\"$comparison\"" >> "$LOG_FILE"
    return
  fi

  if [ "$MODE" = "copy" ]; then
    cp -p "$file" "$final_path"
    echo "\"$file\",\"$final_path\",\"$metadata_date\",\"$media_type\",\"copied\",\"$comparison\"" >> "$LOG_FILE"
    echo "[COPIED] $file -> $final_path [$media_type/$comparison]"
  elif [ "$MODE" = "move" ]; then
    mv "$file" "$final_path"
    echo "\"$file\",\"$final_path\",\"$metadata_date\",\"$media_type\",\"moved\",\"$comparison\"" >> "$LOG_FILE"
    echo "[MOVED] $file -> $final_path [$media_type/$comparison]"
  fi
}

echo "Mode: $MODE"
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "Split media: $SPLIT_MEDIA"
echo "Log file: $LOG_FILE"
echo "Skipped file: $SKIPPED_FILE"
echo ""

find "$SOURCE_DIR" -type f \( \
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
  -iname "*.webp" -o \
  -iname "*.bmp"  -o \
  -iname "*.mov"  -o \
  -iname "*.mp4"  -o \
  -iname "*.m4v"  -o \
  -iname "*.avi"  -o \
  -iname "*.mkv"  -o \
  -iname "*.3gp"  -o \
  -iname "*.3g2"  -o \
  -iname "*.mts"  -o \
  -iname "*.m2ts" -o \
  -iname "*.mpg"  -o \
  -iname "*.mpeg" -o \
  -iname "*.wmv" \
\) -print0 | while IFS= read -r -d '' file; do
  process_file "$file"
done

echo ""
echo "Done."
echo "Log: $LOG_FILE"
echo "Skipped: $SKIPPED_FILE"
