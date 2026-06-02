#!/bin/bash

while true; do
  date
  free -h
  ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -10
  sleep 60
done >> ~/memwatch/spike.log
