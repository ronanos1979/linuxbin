#!/bin/bash

set -u

OUTPUT_DIR="./output"
mkdir -p "$OUTPUT_DIR"

find . -type f ! -path "./output/*" ! -name "$(basename "$0")" -print0 | while IFS= read -r -d '' file; do
  filename="$(basename "$file")"
  target="$OUTPUT_DIR/$filename"

  if [ -e "$target" ]; then
    stem="${filename%.*}"
    ext="${filename##*.}"

    if [ "$stem" = "$ext" ]; then
      # File has no extension
      counter=1
      while [ -e "$OUTPUT_DIR/${filename}_duplicate_${counter}" ]; do
        counter=$((counter + 1))
      done
      target="$OUTPUT_DIR/${filename}_duplicate_${counter}"
    else
      counter=1
      while [ -e "$OUTPUT_DIR/${stem}_duplicate_${counter}.${ext}" ]; do
        counter=$((counter + 1))
      done
      target="$OUTPUT_DIR/${stem}_duplicate_${counter}.${ext}"
    fi
  fi

  echo "Moving: $file -> $target"
  mv "$file" "$target"
done

echo "Done. Files moved to: $OUTPUT_DIR"
