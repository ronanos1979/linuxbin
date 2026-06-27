#!/bin/bash

# compare_to_parent.sh
# Run this from the folder containing the files you want to check.

different_files=()

while IFS= read -r -d '' file; do
    filename="$(basename "$file")"
    parent_file="../$filename"

    if [ ! -f "$parent_file" ]; then
        different_files+=("$filename - missing from parent folder")
        continue
    fi

    current_hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    parent_hash="$(shasum -a 256 "$parent_file" | awk '{print $1}')"

    if [ "$current_hash" != "$parent_hash" ]; then
        different_files+=("$filename - exists in parent but is different")
    fi

done < <(find . -maxdepth 1 -type f -print0)

echo
echo "Comparison complete."
echo

if [ ${#different_files[@]} -eq 0 ]; then
    echo "No differences found. Every file in the current folder exists identically in the parent folder."
else
    echo "Files missing or different in parent folder:"
    echo "--------------------------------------------"
    for item in "${different_files[@]}"; do
        echo "$item"
    done
fi
