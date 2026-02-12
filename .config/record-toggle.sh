#!/bin/bash
# ~/Scripts/record-toggle.sh

PIDFILE="/tmp/wf-recorder.pid"

if [[ -f "$PIDFILE" ]]; then
    # Stop recording
    kill -INT "$(cat "$PIDFILE")"
    rm "$PIDFILE"
    notify-send "Recording Stopped" "Video saved" -i video-x-generic
else
    # Start recording (full screen)
    wf-recorder -f ~/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4 &
    echo $! > "$PIDFILE"
    notify-send "Recording Started" "Full screen capture" -i media-record
fi