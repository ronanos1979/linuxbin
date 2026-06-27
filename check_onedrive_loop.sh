OUT="/tmp/onedrive_real_loop_check_$(date +%Y%m%d_%H%M%S).log"

echo "Watching OneDrive item activity for 2 minutes..."
perl -e 'alarm 120; exec @ARGV' \
log stream --style compact --predicate 'process == "fileproviderd" OR process CONTAINS[c] "OneDrive"' 2>/dev/null | \
egrep --line-buffered -i 'com.microsoft.OneDrive.FileProvider|FP snapshot mutation|create-item|update-item|delete-item|itemChangedRemotely|diskImport|contentUpdate| n:"' | \
egrep --line-buffered -v 'spotlight|FrontBoard|boringssl|network|Connection reset|NSSceneFenceAction' | \
sed -E 's/^([0-9-]+ [0-9:.]+).* n:"([^"]+)".*/\1  \2/' | \
tee "$OUT"

echo
echo "===== TOP REPEATED REAL ITEMS ====="
awk '{$1=""; $2=""; sub(/^  /,""); print}' "$OUT" | sort | uniq -c | sort -nr | head -30

echo
echo "===== CURRENT CHECK ====="
~/bin/check_onedrive.sh
