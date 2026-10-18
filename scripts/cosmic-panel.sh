#!/usr/bin/env bash
# Hides (or shows again) COSMIC's own top panel: JellyFace has its own top dropdown dashboard and side bar.
# Only the panel list in your COSMIC config changes, tracked, so `jellyface revert-system` also brings it back.
#   cosmic-panel.sh hide|show|status
set -uo pipefail
. "$(dirname "$0")/lib.sh"

F="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel/v1/entries"
case "${1:-status}" in
    hide)   cosmic_entries remove Panel; log "COSMIC top panel hidden" ;;
    show)   cosmic_entries add Panel; log "COSMIC top panel shown" ;;
    status) log "COSMIC panels: $(cat "$F" 2>/dev/null || echo '["Panel"] (default)')" ;;
    *) echo "usage: cosmic-panel.sh hide|show|status" >&2; exit 2 ;;
esac
