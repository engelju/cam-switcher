#!/usr/bin/env bash
# sony-a6000-watchdog.sh
# Continuous watchdog that monitors your Sony a6000 video stream.
# It detects when the camera is connected/disconnected and alerts you.
#
# Usage: ./sony-a6000-watchdog.sh [check_interval_seconds]
# Example: ./sony-a6000-watchdog.sh 10  (checks every 10 seconds)

set -uo pipefail

CHECK_INTERVAL="${1:-10}"
CAM_LINK_NAME="Cam Link 4K"
CAM_INPUT="${CAM_LINK_NAME}:none"  # select by name, not index — device order can change
LOG_FILE="/tmp/sony-a6000-watchdog.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Colours go to the terminal; the log file gets plain text.
log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo -e "$line"
    echo -e "$line" | sed $'s/\033\\[[0-9;]*m//g' >> "$LOG_FILE"
}

# Capture output before grepping: ffmpeg always exits non-zero here ("dummy"
# isn't a real input), which with pipefail would make a piped grep look failed.
is_cam_link_connected() {
    local output
    output=$(ffmpeg -list_devices true -f avfoundation -i dummy 2>&1)
    grep -q "$CAM_LINK_NAME" <<< "$output"
}

# avfoundation refuses any framerate the device doesn't offer (the Cam Link
# only offers whatever the camera sends over HDMI, e.g. 50fps for PAL).
# Request an unsupported rate and read the supported one from the error.
detect_framerate() {
    local output
    output=$(ffmpeg -hide_banner -f avfoundation -framerate 1 -i "$CAM_INPUT" -frames:v 1 -f null - 2>&1)
    grep -oE '@\[[0-9.]+' <<< "$output" | head -1 | tr -d '@['
}

is_video_active() {
    local fps output
    fps=$(detect_framerate)
    [ -n "$fps" ] || return 1
    output=$(ffmpeg -hide_banner -f avfoundation -framerate "$fps" -i "$CAM_INPUT" -frames:v 1 -f null - 2>&1)
    grep -q "frame=" <<< "$output"
}

# Check if camera was previously detected (for state tracking)
PREV_CONNECTED=false
PREV_VIDEO=false

log "═══════════════════════════════════════════════════"
log "Sony a6000 Watchdog started (checking every ${CHECK_INTERVAL}s)"
log "Log file: $LOG_FILE"
log "Press Ctrl+C to stop"
log "═══════════════════════════════════════════════════"

trap 'log "Watchdog stopped by user."; exit 0' INT TERM

while true; do
    current_connected=false
    current_video=false
    
    if is_cam_link_connected; then
        current_connected=true
        if is_video_active; then
            current_video=true
        fi
    fi
    
    # State change detection
    if $current_connected && ! $PREV_CONNECTED; then
        log ""
        log "${GREEN}▶ CAMERA CONNECTED${NC} — $CAM_LINK_NAME detected"
    elif ! $current_connected && $PREV_CONNECTED; then
        log ""
        log "${RED}◀ CAMERA DISCONNECTED${NC} — $CAM_LINK_NAME no longer detected"
        log "${YELLOW}⚠️  If the camera was ON, it may have switched to slideshow mode.${NC}"
        log "${YELLOW}   Fix: Set 'Power On/Off Setting' → 'Camera' in the camera menu.${NC}"
    fi
    
    if $current_video; then
        if ! $PREV_VIDEO; then
            log "${GREEN}  → Video stream active${NC}"
        fi
    else
        if $PREV_VIDEO; then
            log "${YELLOW}  → Video stream stopped${NC}"
        fi
    fi
    
    # Print status line
    if $current_connected; then
        if $current_video; then
            echo -e "${GREEN}  ● Connected${NC} | Video: ${GREEN}Active${NC}"
        else
            echo -e "${YELLOW}  ● Connected${NC} | Video: ${YELLOW}No stream${NC}"
        fi
    else
        echo -e "${RED}  ○ Not connected${NC}"
    fi
    
    PREV_CONNECTED=$current_connected
    PREV_VIDEO=$current_video
    
    sleep "$CHECK_INTERVAL"
done
