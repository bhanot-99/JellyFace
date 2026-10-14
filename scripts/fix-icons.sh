#!/usr/bin/env bash
# Creates icon aliases (symlinks in ~/.local/share/icons/hicolor) listed in config/icon-aliases.txt,
# so tray icons that ask for an unknown name show the real app icon instead of a checkerboard.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$DATA/icons/hicolor"
SEARCH=("$DATA/flatpak/exports/share/icons/hicolor" /var/lib/flatpak/exports/share/icons/hicolor /usr/share/icons/hicolor)
made=0
while read -r alias target; do
    [[ -z "${alias:-}" || "$alias" == \#* ]] && continue
    for base in "${SEARCH[@]}"; do
        for src in "$base"/*/apps/"$target".{png,svg}; do
            [ -e "$src" ] || continue
            size="$(basename "$(dirname "$(dirname "$src")")")"
            out="$DEST/$size/apps/$alias.${src##*.}"
            [ -e "$out" ] && continue          # never overwrite an existing icon
            mkdir -p "$(dirname "$out")"
            ln -s "$(readlink -f "$src")" "$out"
            made=$((made + 1))
        done
    done
done < "$JF_ROOT/config/icon-aliases.txt"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$DEST" 2>/dev/null || true
log "icon aliases: $made created"
