#!/usr/bin/env bash
# Pop out all JellyFace panels at once for a specified duration (default: 5 seconds)
# Panels:
#   - Top dropdown dashboard
#   - Right-side panel: Volume & Brightness (OSD), Notifications (sidebar), Bottom-down (utilities)
#   - Left-side app drawer (launcher)
#   - Status popouts: WiFi, Bluetooth, Battery
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
JF_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$JF_ROOT/scripts/lib.sh"

DURATION="${1:-5}"

if ! [[ "$DURATION" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    die "Duration must be a positive number of seconds. Got: '$DURATION'"
fi

if ! pgrep -f "$JF_QS_RE" >/dev/null; then
    die "JellyFace shell is not running. Start it with: jellyface start"
fi

log "Popping out all panels for ${DURATION}s..."

# Ensure all panels are closed if interrupted
cleanup() {
    "$JF_ROOT/bin/jellyface" ipc drawers closeAll >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Integer seconds for Quickshell IPC
INT_SECS="${DURATION%%.*}"
{ [ -z "$INT_SECS" ] || [ "$INT_SECS" -le 0 ]; } && INT_SECS=1
# the shell closes everything after INT_SECS; wait the same time so the cleanup below never cuts it short
DURATION="$INT_SECS"

# Trigger all panels and status popouts in the shell
"$JF_ROOT/bin/jellyface" ipc drawers popAll "$INT_SECS" >/dev/null 2>&1 || die "could not reach the shell (is it running? try: jellyface status)"

sleep "$DURATION"

log "Panels closed."
