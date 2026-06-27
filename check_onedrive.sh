echo "===== DATE ====="; date; echo

echo "===== ONEDRIVE STATUS / CPU ====="
ps -axo pid,%cpu,%mem,etime,command | egrep -i '[O]neDrive|[F]ileProvider|fileproviderd' | sort -k2 -nr
echo

echo "===== COUNT REMAINING FILES ====="
find "$HOME/Library/CloudStorage/OneDrive-Personal" -type f 2>/dev/null | wc -l
echo

echo "===== RECENT FILE CHANGES LAST 15 MINUTES ====="
find "$HOME/Library/CloudStorage/OneDrive-Personal" -type f -mmin -15 -print 2>/dev/null | tail -50
