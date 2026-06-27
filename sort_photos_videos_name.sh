#!/bin/bash

# sort_photo_video_names.sh
#
# Sorts files named like:
#   PHOTO-2021-07-30-20-16-58.jpg
#   VIDEO-2020-10-27-16-59-19.mp4
#
# Into:
#   output/Photos/YYYY/MM-Month/YYYY-MM-DD/
#   output/Videos/YYYY/MM-Month/YYYY-MM-DD/
#
# Usage:
#   ./sort_photo_video_names.sh --dry-run
#   ./sort_photo_video_names.sh --move

set -u

MODE="dry-run"
OUTPUT_DIR="./output"

if [ "$#" -lt 1 ]; then
  echo "Usage:"
  echo "  $0 --dry-run"
  echo "  $0 --move"
  exit 1
fi

case "$1" in
  --dry-run)
    MODE="dry-run"
    ;;
  --move)
    MODE="move"
    ;;
  *)
    echo "Invalid mode: $1"
    echo "Use --dry-run or --move"
    exit 1
    ;;
esac

month_name() {
  case "$1" in
    01) echo "January" ;;
    02) echo "February" ;;
    03) echo "March" ;;
    04) echo "April" ;;
    05) echo "May" ;;
    06) echo "June" ;;
    07) echo "July" ;;
    08) echo "August" ;;
    09) echo "September" ;;
    10) echo "October" ;;
    11) echo "November" ;;
    12) echo "December" ;;
    *) echo "Unknown" ;;
  esac
}

media_folder() {
  local filename="$1"
  local upper
  upper="$(echo "$filename" | tr '[:lower:]' '[:upper:]')"

  if [[ "$upper" == PHOTO-* ]]; then
    echo "Photos"
  elif [[ "$upper" == VIDEO-* ]]; then
    echo "Videos"
  else
    echo "Unknown"
  fi
}

make_unique_path() {
  local path="$1"

  if [ ! -e "$path" ]; then
    echo "$path"
    return
  fi

  local dir
  local base
  local stem
  local ext
  local counter
  local candidate

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [[ "$base" == *.* ]]; then
    stem="${base%.*}"
    ext="${base##*.}"
  else
    stem="$base"
    ext=""
  fi

  counter=1

  while true; do
    if [ -n "$ext" ]; then
      candidate="$dir/${stem}_duplicate_${counter}.${ext}"
    else
      candidate="$dir/${stem}_duplicate_${counter}"
    fi

    if [ ! -e "$candidate" ]; then
      echo "$candidate"
      return
    fi

    counter=$((counter + 1))
  done
}

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="./sort_photo_video_names_$TIMESTAMP.csv"
SKIPPED_FILE="./sort_photo_video_names_skipped_$TIMESTAMP.csv"

echo "source,target,action" > "$LOG_FILE"
echo "source,reason" > "$SKIPPED_FILE"

echo "Mode: $MODE"
echo "Output folder: $OUTPUT_DIR"
echo "Log: $LOG_FILE"
echo "Skipped: $SKIPPED_FILE"
echo ""

find . -maxdepth 1 -type f ! -name "$(basename "$0")" ! -name "sort_photo_video_names_*.csv" -print0 | while IFS= read -r -d '' file; do
  filename="$(basename "$file")"

  # Match PHOTO-YYYY-MM-DD-HH-MM-SS.ext or VIDEO-YYYY-MM-DD-HH-MM-SS.ext
  if [[ "$filename" =~ ^(PHOTO|Photo|photo|VIDEO|Video|video)-([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})\..+$ ]]; then
    year="${BASH_REMATCH[2]}"
    month="${BASH_REMATCH[3]}"
    day="${BASH_REMATCH[4]}"

    media="$(media_folder "$filename")"

    if [ "$media" = "Unknown" ]; then
      echo "[SKIP] $filename - unknown media type"
      echo "\"$file\",\"Unknown media type\"" >> "$SKIPPED_FILE"
      continue
    fi

    mname="$(month_name "$month")"

    if [ "$mname" = "Unknown" ]; then
      echo "[SKIP] $filename - invalid month"
      echo "\"$file\",\"Invalid month: $month\"" >> "$SKIPPED_FILE"
      continue
    fi

    date_folder="${year}-${month}-${day}"
    target_dir="$OUTPUT_DIR/$media/$year/$month-$mname/$date_folder"
    target_path="$target_dir/$filename"
    target_path="$(make_unique_path "$target_path")"

    if [ "$MODE" = "dry-run" ]; then
      echo "[DRY RUN] $file"
      echo "          -> $target_path"
      echo "\"$file\",\"$target_path\",\"dry-run\"" >> "$LOG_FILE"
    else
      mkdir -p "$target_dir"
      mv "$file" "$target_path"
      echo "[MOVED] $file -> $target_path"
      echo "\"$file\",\"$target_path\",\"moved\"" >> "$LOG_FILE"
    fi
  else
    echo "[SKIP] $filename - filename does not match expected pattern"
    echo "\"$file\",\"Filename does not match PHOTO-YYYY-MM-DD-HH-MM-SS or VIDEO-YYYY-MM-DD-HH-MM-SS pattern\"" >> "$SKIPPED_FILE"
  fi
done

echo ""
echo "Done."
echo "Log: $LOG_FILE"
echo "Skipped: $SKIPPED_FILE"
