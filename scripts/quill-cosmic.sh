#!/usr/bin/env bash
# COSMIC settings that follow Quill (scripts/ui.sh, Appearance). Every file is tracked, so `jellyface revert-system`
# puts it back.
#   quill-cosmic.sh mode light|dark   COSMIC's own apps follow Quill's light or dark theme (Appearance → Theme)
#   quill-cosmic.sh gaps none         tiled windows fill the screen like a maximized one: no gaps around or between them
#   quill-cosmic.sh gaps restore      COSMIC's gaps as they were before (saved the first time `none` ran)
set -euo pipefail
. "$(dirname "$0")/lib.sh"

C="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic"
F="$C/com.system76.CosmicTheme.Mode/v1/is_dark"
# COSMIC keeps the gaps in its theme: the light and dark themes and the builders the settings app writes them from
GAP_DIRS=(com.system76.CosmicTheme.Dark com.system76.CosmicTheme.Dark.Builder com.system76.CosmicTheme.Light com.system76.CosmicTheme.Light.Builder)
SAVED="$JF_STATE_DIR/quill-gaps"

case "${1:-}:${2:-}" in
    mode:light|mode:dark)
        want=$([ "$2" = dark ] && echo true || echo false)
        [ "$(cat "$F" 2>/dev/null)" = "$want" ] && exit 0
        sys_track "$F"
        mkdir -p "$(dirname "$F")"
        printf '%s' "$want" > "$F" ;;
    gaps:none)
        mkdir -p "$JF_STATE_DIR"
        # every config version the installed COSMIC ships (v1, v2 ...): its compositor reads the newest one
        files=()
        for d in "${GAP_DIRS[@]}"; do
            for vdir in /usr/share/cosmic/"$d"/v*; do
                [ -d "$vdir" ] && files+=("$C/$d/$(basename "$vdir")/gaps")
            done
        done
        for g in "${files[@]}"; do
            grep -qxF -- "$g" <(cut -f1 "$SAVED" 2>/dev/null) || printf '%s\t%s\n' "$g" "$(cat "$g" 2>/dev/null || echo -)" >> "$SAVED"
        done
        for g in "${files[@]}"; do
            [ "$(cat "$g" 2>/dev/null)" = "(0, 0)" ] && continue
            sys_track "$g"
            mkdir -p "$(dirname "$g")"
            printf '(0, 0)' > "$g"
        done ;;
    gaps:restore)
        [ -e "$SAVED" ] || exit 0
        while IFS=$'\t' read -r g v; do
            case "$g" in /*) ;; *) continue ;; esac   # (lines from an older format)
            if [ "$v" = - ]; then rm -f "$g"; else printf '%s' "$v" > "$g"; fi
        done < "$SAVED"
        rm -f "$SAVED" ;;
    *) die "usage: quill-cosmic.sh mode light|dark | gaps none|restore" ;;
esac
