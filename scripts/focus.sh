#!/usr/bin/env bash
# Focus follows the cursor: whichever window is under the pointer gets the keyboard, no click needed (the same switch as
# COSMIC Settings -> Desktop -> Window management). JellyFace's own panels (launcher, sidebar, session) do the same
# themselves while open. Tracked: `jellyface revert-system` restores the previous values.
#   focus.sh on|off|status
set -uo pipefail
. "$(dirname "$0")/lib.sh"

D="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicComp/v1"
case "${1:-status}" in
    on)  sys_track "$D"; mkdir -p "$D"; printf 'true' > "$D/focus_follows_cursor"; printf '0' > "$D/focus_follows_cursor_delay"
         log "focus follows cursor: on (no delay)" ;;
    off) sys_track "$D"; mkdir -p "$D"; printf 'false' > "$D/focus_follows_cursor"; log "focus follows cursor: off" ;;
    status) log "focus follows cursor: $(cat "$D/focus_follows_cursor" 2>/dev/null || echo 'off (default)')" ;;
    *) echo "usage: focus.sh on|off|status" >&2; exit 2 ;;
esac
