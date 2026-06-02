#!/bin/bash

threshold=10
speed=2

read startx starty <<< $(xdotool getmouselocation --shell | grep -E 'X|Y' | cut -d= -f2 | xargs)

while xdotool getmouselocation --shell | grep BUTTONS | grep -q 2; do
    read x y <<< $(xdotool getmouselocation --shell | grep -E 'X|Y' | cut -d= -f2 | xargs)

    dy=$((y - starty))

    if [ $dy -gt $threshold ]; then
        xdotool click --repeat $speed 5
    elif [ $dy -lt -$threshold ]; then
        xdotool click --repeat $speed 4
    fi

    sleep 0.02
done
