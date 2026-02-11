#!/bin/zsh

# Configuration
readonly LOCK_FILE="/tmp/swww_wallpaper_lock"
readonly LOGFILE="/tmp/swww_wallpaper.log"
readonly MAX_ATTEMPTS=5
readonly COOLDOWN=1
readonly RESIZE_MODE="fit"  # Options: crop (fill), fit, tile, no
readonly TRANSITION_TYPE="wipe"
readonly TRANSITION_ANGLE=30
readonly TRANSITION_FPS=60
readonly TRANSITION_DURATION=1
readonly SWWW_READY_TIMEOUT=10
readonly SWWW_READY_POLL=0.2
readonly RETRY_DELAY=0.5

# Wallpaper collection
declare -r WALLPAPERS=(
  "$HOME/Pictures/Wallpaper/gruvspace.jpg"
  "$HOME/Pictures/Wallpaper/skull.png"
  "$HOME/Pictures/Wallpaper/gruv.png"
)

# Deduplicate array
declare -r UNIQUE_WALLPAPERS=("${(@u)WALLPAPERS}")

# ============================================================================
# Wait for swww daemon to be ready
# ============================================================================
wait_for_swww() {
  local attempt
  for (( attempt = 1; attempt <= SWWW_READY_TIMEOUT; attempt++ )); do
    if swww query >/dev/null 2>&1; then
      return 0
    fi
    sleep "$SWWW_READY_POLL"
  done
  
  log_error "swww-daemon not ready after ${SWWW_READY_TIMEOUT}s"
  return 1
}

# ============================================================================
# Enforce cooldown period to prevent rapid successive changes
# ============================================================================
check_cooldown() {
  local current_time lock_time elapsed
  
  if [[ ! -f "$LOCK_FILE" ]]; then
    date +%s > "$LOCK_FILE"
    return 0
  fi
  
  current_time=$(date +%s)
  lock_time=$(<"$LOCK_FILE")
  elapsed=$(( current_time - lock_time ))
  
  if (( elapsed < COOLDOWN )); then
    log_info "Cooldown active (${elapsed}s/${COOLDOWN}s)"
    return 1
  fi
  
  date +%s > "$LOCK_FILE"
  return 0
}

# ============================================================================
# Select random wallpaper from collection
# ============================================================================
pick_random_wallpaper() {
  local count=${#UNIQUE_WALLPAPERS[@]}
  
  if (( count == 0 )); then
    log_error "No wallpapers configured"
    return 1
  fi
  
  # zsh arrays are 1-indexed
  local idx=$(( (RANDOM % count) + 1 ))
  printf '%s\n' "${UNIQUE_WALLPAPERS[idx]}"
}

# ============================================================================
# Validate wallpaper file exists
# ============================================================================
validate_wallpaper() {
  local wallpaper="$1"
  
  if [[ -z "$wallpaper" || ! -e "$wallpaper" ]]; then
    log_error "Invalid wallpaper path: '$wallpaper'"
    return 1
  fi
}

# ============================================================================
# Apply wallpaper with retry logic
# ============================================================================
set_wallpaper() {
  local wallpaper="$1"
  local attempt
  
  validate_wallpaper "$wallpaper" || return 1
  
  for (( attempt = 1; attempt <= MAX_ATTEMPTS; attempt++ )); do
    log_info "Attempt $attempt/$MAX_ATTEMPTS: $wallpaper"
    
    if swww img "$wallpaper" \
      --transition-type="$TRANSITION_TYPE" \
      --transition-angle="$TRANSITION_ANGLE" \
      --transition-fps="$TRANSITION_FPS" \
      --transition-duration="$TRANSITION_DURATION" \
      --resize="$RESIZE_MODE" >> "$LOGFILE" 2>&1; then
      
      log_success "Wallpaper applied successfully"
      return 0
    fi
    
    log_error "Attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
  done
  
  log_error "Failed to apply wallpaper after $MAX_ATTEMPTS attempts"
  return 1
}

# ============================================================================
# Logging utilities
# ============================================================================
log_info() {
  printf '[%s] [INFO] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$1" >> "$LOGFILE"
}

log_success() {
  printf '[%s] [SUCCESS] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$1" >> "$LOGFILE"
}

log_error() {
  printf '[%s] [ERROR] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$1" >> "$LOGFILE"
}

# ============================================================================
# Main orchestration
# ============================================================================
main() {
  wait_for_swww || exit 1
  check_cooldown || exit 0
  
  local wallpaper
  wallpaper="$(pick_random_wallpaper)" || exit 1
  
  set_wallpaper "$wallpaper"
}

main "$@"