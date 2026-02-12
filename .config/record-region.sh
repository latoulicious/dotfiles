#!/usr/bin/env bash
set -euo pipefail

# Ensure proper Wayland environment for keybind execution
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

# Try to detect the correct Wayland display if not set
if [ -z "$WAYLAND_DISPLAY" ]; then
    for socket in /run/user/$(id -u)/wayland-*; do
        if [ -S "$socket" ]; then
            export WAYLAND_DISPLAY="$(basename "$socket")"
            break
        fi
    done
fi

# Ensure we can access the Wayland compositor
if [ ! -S "/run/user/$(id -u)/$WAYLAND_DISPLAY" ]; then
    log_msg "ERROR: Cannot access Wayland display: $WAYLAND_DISPLAY"
    exit 1
fi

VIDDIR="$HOME/Videos"
LOG="/tmp/wf-record.log"

mkdir -p "$VIDDIR"

# Function to log with timestamp
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log_msg "Script started from: $0"
log_msg "PWD: $(pwd)"
log_msg "USER: $USER"
log_msg "PATH: $PATH"

if pgrep -x wf-recorder >/dev/null; then
    log_msg "Stopping existing wf-recorder"
    pkill -SIGINT -x wf-recorder
    if command -v notify-send >/dev/null; then
        notify-send "Screen Recorder" "Stopped & saved."
    fi
else
    OUT="$VIDDIR/recording-$(date +%Y%m%d-%H%M%S).mp4"
    log_msg "Starting region recording to: $OUT"
    
    if command -v notify-send >/dev/null; then
        notify-send "Screen Recorder" "Recording REGION… Press hotkey again to stop."
    fi
    
    # Use absolute paths and add more debugging
    log_msg "Running slurp..."
    if ! SLURP_OUTPUT=$(/usr/bin/slurp 2>>"$LOG"); then
        log_msg "ERROR: slurp failed"
        if command -v notify-send >/dev/null; then
            notify-send "Screen Recorder" "Failed to select region"
        fi
        exit 1
    fi
    log_msg "Slurp output: $SLURP_OUTPUT"
    
    # Get system audio monitor device (PipeWire compatible)
    AUDIO_SOURCE=$(pactl list sources short | grep -E "monitor|\.monitor" | head -1 | cut -f2)
    
    # Fallback to default sink monitor if specific monitor not found
    if [ -z "$AUDIO_SOURCE" ]; then
        DEFAULT_SINK=$(pactl get-default-sink)
        if [ -n "$DEFAULT_SINK" ]; then
            AUDIO_SOURCE="${DEFAULT_SINK}.monitor"
        fi
    fi
    
    if [ -z "$AUDIO_SOURCE" ]; then
        log_msg "No monitor audio source found, recording without audio"
        AUDIO_ARG=""
    else
        log_msg "Using audio source: $AUDIO_SOURCE"
        AUDIO_ARG="-a $AUDIO_SOURCE"
    fi
    
    log_msg "Starting wf-recorder..."
    /usr/bin/wf-recorder $AUDIO_ARG -f "$OUT" -g "$SLURP_OUTPUT" >>"$LOG" 2>&1 &
    WF_PID=$!
    
    # Give wf-recorder a moment to start
    sleep 0.5
    
    # Check if the process is still running
    if ! kill -0 "$WF_PID" 2>/dev/null; then
        log_msg "ERROR: wf-recorder failed to start (PID: $WF_PID)"
        if command -v notify-send >/dev/null; then
            notify-send "Screen Recorder" "Failed to start recording"
        fi
        exit 1
    fi
    
    log_msg "Started wf-recorder with PID: $WF_PID"
fi