echo "===== 1) TOP CPU PROCESSES ====="
ps -arcwwwxo pid,ppid,%cpu,%mem,etime,comm | head -25

echo
echo "===== 2) TOP SNAPSHOT ====="
top -l 1 -o cpu -n 20

echo
echo "===== 3) THERMAL STATE ====="
pmset -g therm

echo
echo "===== 4) BATTERY / POWER ====="
pmset -g batt

echo
echo "===== 5) SPOTLIGHT INDEXING STATUS ====="
mdutil -s /

echo
echo "===== 6) COMMON BACKGROUND PROCESSES ====="
ps aux | egrep 'mds|mdworker|photoanalysisd|cloudphotod|bird|cloudd|backupd|Time Machine|Google|Chrome|Dropbox|OneDrive' | grep -v egrep

echo
echo "===== 7) RECENT THERMAL / FAN LOGS ====="
log show --predicate 'eventMessage CONTAINS[c] "thermal" OR eventMessage CONTAINS[c] "fan" OR eventMessage CONTAINS[c] "CPU"' --last 30m --style compact | tail -80

echo
echo "===== 8) MEMORY PRESSURE ====="
memory_pressure

echo
echo "===== 9) OPTIONAL CPU TEMP TOOL CHECK ====="
if command -v osx-cpu-temp >/dev/null 2>&1; then
  osx-cpu-temp
else
  echo "osx-cpu-temp not installed"
fi

echo
echo "===== DONE ====="
