#!/usr/bin/env bash
# Hides (or shows again) COSMIC's own dock: JellyFace has its own. Only the panel list in your COSMIC config changes,
# tracked, so `jellyface revert-system` also brings it back.
#   cosmic-dock.sh hide|show|status
set -uo pipefail
. "$(dirname "$0")/lib.sh"

F="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel/v1/entries"
case "${1:-status}" in
    hide)   cosmic_entries remove Dock; log "COSMIC dock hidden" ;;
    show)   cosmic_entries add Dock; log "COSMIC dock shown" ;;
    status) log "COSMIC panels: $(cat "$F" 2>/dev/null || echo '["Panel","Dock"] (default)')" ;;
    *) echo "usage: cosmic-dock.sh hide|show|status" >&2; exit 2 ;;
esac
