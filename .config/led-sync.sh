#!/bin/bash

OUTPUT_LED="/sys/class/leds/hda::mute/brightness"
MIC_LED="/sys/class/leds/hda::micmute/brightness"

OUTPUT_STATE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
MIC_STATE=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)

# Output mute LED
if [[ "$OUTPUT_STATE" == *"[MUTED]"* ]]; then
    echo 1 | sudo tee "$OUTPUT_LED" > /dev/null
else
    echo 0 | sudo tee "$OUTPUT_LED" > /dev/null
fi

# Mic mute LED
if [[ "$MIC_STATE" == *"[MUTED]"* ]]; then
    echo 1 | sudo tee "$MIC_LED" > /dev/null
else
    echo 0 | sudo tee "$MIC_LED" > /dev/null
fi
