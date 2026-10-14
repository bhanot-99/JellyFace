#!/usr/bin/env bash
# Automatic tiling with COSMIC's own tiling window manager: windows on a workspace share the space instead of
# overlapping. JellyFace's bar and border already reserve their space, so tiles never slide under them.
# Tracked: `jellyface revert-system` restores the previous values.
#   tiling.sh on|off|status
set -uo pipefail
. "$(dirname "$0")/lib.sh"

D="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicComp/v1"
case "${1:-status}" in
    on)  sys_track "$D"; mkdir -p "$D"; printf 'Global' > "$D/autotile_behavior"; printf 'true' > "$D/autotile"
         log "auto-tiling: on (all workspaces)" ;;
    off) sys_track "$D"; mkdir -p "$D"; printf 'false' > "$D/autotile"; log "auto-tiling: off" ;;
    status) log "auto-tiling: $(cat "$D/autotile" 2>/dev/null || echo 'off (default)') ($(cat "$D/autotile_behavior" 2>/dev/null))" ;;
    *) echo "usage: tiling.sh on|off|status" >&2; exit 2 ;;
esac
