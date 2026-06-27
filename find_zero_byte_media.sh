#!/bin/bash

# Find 0-byte media files under current folder.
# Safe: does not delete or move anything.

ROOT="${1:-.}"
OUT="zero_byte_media_$(date +%Y%m%d_%H%M%S).txt"
CSV="zero_byte_media_$(date +%Y%m%d_%H%M%S).csv"

echo "Scanning: $ROOT"
echo "Output text: $OUT"
echo "Output CSV : $CSV"
echo

# Media extensions to check
find "$ROOT" -type f -size 0c \( \
  -iname "*.jpg"  -o -iname "*.jpeg" -o -iname "*.jpe"  -o \
  -iname "*.png"  -o -iname "*.gif"  -o -iname "*.bmp"  -o \
  -iname "*.tif"  -o -iname "*.tiff" -o -iname "*.webp" -o \
  -iname "*.heic" -o -iname "*.heif" -o \
  -iname "*.raw"  -o -iname "*.dng"  -o -iname "*.cr2"  -o \
  -iname "*.nef"  -o -iname "*.arw"  -o -iname "*.orf"  -o \
  -iname "*.rw2"  -o \
  -iname "*.mov"  -o -iname "*.mp4"  -o -iname "*.m4v"  -o \
  -iname "*.avi"  -o -iname "*.mkv"  -o -iname "*.wmv"  -o \
  -iname "*.mpg"  -o -iname "*.mpeg" -o -iname "*.3gp"  -o \
  -iname "*.mts"  -o -iname "*.m2ts" -o \
  -iname "*.mp3"  -o -iname "*.m4a"  -o -iname "*.aac"  -o \
  -iname "*.wav"  -o -iname "*.flac" -o -iname "*.aiff" -o \
  -iname "*.aif" \
\) -print 2>/dev/null | sort > "$OUT"

COUNT=$(wc -l < "$OUT" | tr -d ' ')

echo "path" > "$CSV"
sed 's/"/""/g; s/^/"/; s/$/"/' "$OUT" >> "$CSV"

echo
echo "Found $COUNT zero-byte media files."
echo

if [ "$COUNT" -gt 0 ]; then
  echo "First 50:"
  head -50 "$OUT"
  echo
  echo "Full list saved to:"
  echo "$OUT"
  echo "$CSV"
else
  echo "No zero-byte media files found."
fi
