#!/bin/bash

mkdir -p ~/memwatch
while true; do
  date >> ~/memwatch/mem.log
  free -h >> ~/memwatch/mem.log
  ps -eo pid,user,comm,%mem,rss,vsz --sort=-rss | head -20 >> ~/memwatch/mem.log
  echo "----" >> ~/memwatch/mem.log
  sleep 300
done
