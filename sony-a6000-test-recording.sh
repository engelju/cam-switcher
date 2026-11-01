#!/usr/bin/env bash
# sony-a6000-test-recording.sh
# Records a 5 second test clip from the Cam Link 4K so you can check the picture.
#
# Usage: ./sony-a6000-test-recording.sh [output_file]
# Default output: recordings/sony-a6000-test-<timestamp>.mp4 next to this script

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CAM_INPUT="Cam Link 4K:none"  # select by name, not index — device order can change
DURATION=5
OUTPUT="${1:-$SCRIPT_DIR/recordings/sony-a6000-test-$(date '+%Y%m%d-%H%M%S').mp4}"
mkdir -p "$(dirname "$OUTPUT")"

# avfoundation refuses any framerate the device doesn't offer (the Cam Link
# only offers whatever the camera sends over HDMI, e.g. 50fps for PAL).
# Request an unsupported rate and read the supported one from the error.
output=$(ffmpeg -hide_banner -f avfoundation -framerate 1 -i "$CAM_INPUT" -frames:v 1 -f null - 2>&1 || true)
fps=$(grep -oE '@\[[0-9.]+' <<< "$output" | head -1 | tr -d '@[' || true)
if [ -z "$fps" ]; then
    echo "Could not open Cam Link 4K — is it plugged in and is the camera on?" >&2
    exit 1
fi

# The Cam Link doesn't offer yuv420p (ffmpeg's default request), so ask for nv12.
# macOS itself prints harmless Continuity Camera warnings to stderr that
# -loglevel can't silence, so filter those out.
echo "Recording ${DURATION}s at ${fps}fps → $OUTPUT"
{
    ffmpeg -hide_banner -loglevel error \
        -f avfoundation -framerate "$fps" -pixel_format nv12 -i "$CAM_INPUT" \
        -t "$DURATION" -c:v libx264 -preset veryfast -pix_fmt yuv420p "$OUTPUT" 2>&1 1>&3 \
        | { grep -v 'NSCameraUseContinuityCameraDeviceType' || true; } >&2
} 3>&1

echo "Done: $OUTPUT ($(stat -f%z "$OUTPUT") bytes)"
echo "Open it with: open \"$OUTPUT\""
