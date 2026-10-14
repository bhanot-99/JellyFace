#!/usr/bin/env bash
# Optional: makes COSMIC's own top panel auto-hide and stop reserving space, so JellyFace's bar and
# dashboard are not covered. Backs up the panel config first. Undo with: cosmic-tweaks.sh --revert
set -euo pipefail
. "$(dirname "$0")/lib.sh"

P="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/v1"
[ -d "$P" ] || die "COSMIC panel config not found at $P"

if [ "${1:-}" = "--revert" ]; then
    printf 'Never' > "$P/autohide"; printf 'true' > "$P/exclusive_zone"
    log "COSMIC panel restored to always-visible"
    exit 0
fi
backup "$P"
printf 'Always' > "$P/autohide"       # hide until the cursor touches the top edge
printf 'false'  > "$P/exclusive_zone" # don't reserve space while hidden
log "COSMIC top panel now auto-hides (it re-appears on hover at the top edge)"

# Super+L locks the screen with JellyFace's own lock screen (this replaces COSMIC's default Super+L = "focus window to the right"; COSMIC's own Super+Escape is untouched)
SC="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
if [ -e "$SC" ]; then
    warn "you already have custom shortcuts ($SC); add the Super+L lock shortcut yourself from config/cosmic-shortcuts.ron"
else
    mkdir -p "$(dirname "$SC")"
    sed "s#@JF_ROOT@#$JF_ROOT#g" "$JF_ROOT/config/cosmic-shortcuts.ron" > "$SC"
    log "added shortcut Super+L -> JellyFace lock screen"
fi
