#!/usr/bin/env bash
# Hides (or shows again) COSMIC's own dock: JellyFace has its own. Only the panel list in your COSMIC config changes,
# tracked, so `jellyface revert-system` also brings it back.
#   cosmic-dock.sh hide|show|status
set -uo pipefail
. "$(dirname "$0")/lib.sh"

F="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel/v1/entries"
case "${1:-status}" in
    hide)   sys_track "$F"; mkdir -p "$(dirname "$F")"; printf '["Panel"]' > "$F"; log "COSMIC dock hidden" ;;
    show)   sys_track "$F"; mkdir -p "$(dirname "$F")"; printf '["Panel","Dock"]' > "$F"; log "COSMIC dock shown" ;;
    status) log "COSMIC panels: $(cat "$F" 2>/dev/null || echo '["Panel","Dock"] (default)')" ;;
    *) echo "usage: cosmic-dock.sh hide|show|status" >&2; exit 2 ;;
esac
