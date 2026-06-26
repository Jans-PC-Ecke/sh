#!/bin/bash

command -v xdotool &>/dev/null || { echo "xdotool not found. Please install it." >&2; exit 1; }

active=true
move_distance=10 # Geändert auf 10 für die feste Distanz
current_direction=1 # 1 für nach unten, -1 für nach oben

while true; do
    if $active; then
        xdotool mousemove_relative -- 0 $((move_distance * current_direction))
        current_direction=$((current_direction * -1)) # Richtung umkehren
    fi

    clear
    echo -e "\nt zum Togglen\n-------------\nAutomatische Mausbewegung: $($active && echo aktiv || echo inaktiv)"
    read -t 5 -n 1 key

    if [ "$key" = "t" ]; then
        active=$($active && echo false || echo true)
    fi
done