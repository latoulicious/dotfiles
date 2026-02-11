#!/bin/bash

FIFO="/tmp/cava_fifo"

# Kill existing cava instances
pkill -f "cava -p.*config_waybar"

# Remove old FIFO if exists
rm -f "$FIFO"
mkfifo "$FIFO"

# Start cava in background
cava -p ~/.config/cava/config_waybar &

# Read from FIFO and format for waybar
while read -r line; do
    # Convert cava output to bar characters
    output=""
    for char in $(echo "$line" | grep -o .); do
        case $char in
            0) output+="▁" ;;
            1) output+="▂" ;;
            2) output+="▃" ;;
            3) output+="▄" ;;
            4) output+="▅" ;;
            5) output+="▆" ;;
            6) output+="▇" ;;
            7) output+="█" ;;
        esac
    done
    echo "$output"
done < "$FIFO"
