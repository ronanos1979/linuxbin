#!/bin/bash

# find_duplicates_current_folder.sh
#
# Finds duplicate files in the current directory only.
# A duplicate group means:
#   - same file size
#   - same MD5 checksum
#
# Usage:
#   ./find_duplicates_current_folder.sh

set -u

OUT_FILE="./duplicates_$(date +"%Y%m%d_%H%M%S").txt"
TMP_FILE="$(mktemp)"

echo "Scanning current folder only: $(pwd)"
echo "Output file: $OUT_FILE"
echo ""

# Current directory only, files only, no folders.
find . -maxdepth 1 -type f ! -name "$(basename "$0")" -print0 | while IFS= read -r -d '' file; do
  size="$(stat -f "%z" "$file")"
  md5="$(md5 -q "$file")"
  printf "%s|%s|%s\n" "$size" "$md5" "$file" >> "$TMP_FILE"
done

# Sort by size then hash.
sort "$TMP_FILE" > "${TMP_FILE}.sorted"

duplicate_count=0
group_count=0

{
  echo "Duplicate report"
  echo "Folder: $(pwd)"
  echo "Generated: $(date)"
  echo ""

  awk -F'|' '
  {
    key=$1 "|" $2
    files[key] = files[key] "\n  " $3
    count[key]++
    size[key] = $1
    md5[key] = $2
  }
  END {
    for (key in count) {
      if (count[key] > 1) {
        groups++
        duplicates += count[key]
        print "Duplicate group " groups ":"
        print "  Size: " size[key] " bytes"
        print "  MD5:  " md5[key]
        print files[key]
        print ""
      }
    }

    if (groups == 0) {
      print "No duplicates found."
    } else {
      print "Summary:"
      print "  Duplicate groups: " groups
      print "  Files in duplicate groups: " duplicates
    }
  }
  ' "${TMP_FILE}.sorted"

} | tee "$OUT_FILE"

rm -f "$TMP_FILE" "${TMP_FILE}.sorted"

echo ""
echo "Done."
echo "Report saved to: $OUT_FILE"
