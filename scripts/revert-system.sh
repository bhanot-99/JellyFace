#!/usr/bin/env bash
# Puts back everything JellyFace changed outside its own folder, using the manifest written by sys_track.
# Files that existed are restored from their backup; files JellyFace created are removed. Backups are never deleted.
# Usage: revert-system.sh [--list]
set -uo pipefail
. "$(dirname "$0")/lib.sh"

[ -s "$JF_MANIFEST" ] || { log "nothing to revert (no tracked system changes)"; exit 0; }
if [ "${1:-}" = "--list" ]; then
    awk -F'\t' '{printf "  %-70s %s\n", $1, ($2=="(new)" ? "created by JellyFace" : "was backed up")}' "$JF_MANIFEST"; exit 0
fi

"$JF_ROOT/bin/jellyface" service off >/dev/null 2>&1 || true
tac "$JF_MANIFEST" | while IFS=$'\t' read -r path backup; do
    # sys_track only records files in your home folder: anything else means a damaged manifest, so don't touch it
    case "$path" in "$HOME"/?*) ;; *) warn "skipping unexpected manifest entry '$path'"; continue ;; esac
    case "$path" in *..*|"$JF_ROOT"|"$JF_ROOT"/*) warn "skipping unexpected manifest entry '$path'"; continue ;; esac
    if [ "$backup" = "(new)" ]; then
        [ -e "$path" ] && { rm -rf -- "$path"; log "removed $path (created by JellyFace)"; }
    elif [ -e "$backup" ]; then
        rm -rf -- "$path"; cp -a "$backup" "$path"; log "restored $path"
    else
        warn "backup missing for $path ($backup); left untouched"
    fi
done
mv "$JF_MANIFEST" "$JF_MANIFEST.reverted.$(date +%s)"
log "done. Log out and back in if COSMIC does not pick everything up immediately."
