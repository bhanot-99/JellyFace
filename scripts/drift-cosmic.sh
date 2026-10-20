#!/usr/bin/env bash
# drift-cosmic.sh mode light|dark: make COSMIC's own apps (Files, Terminal, Settings...) follow Drift's light or dark
# theme (Appearance → Theme → "COSMIC apps follow"). Only COSMIC's light/dark switch is changed; the file is tracked, so
# `jellyface revert-system` puts it back.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
case "${1:-}:${2:-}" in
    mode:light|mode:dark)
        want=$([ "$2" = dark ] && echo true || echo false)
        [ "$(cat "$F" 2>/dev/null)" = "$want" ] && exit 0
        sys_track "$F"
        mkdir -p "$(dirname "$F")"
        printf '%s' "$want" > "$F" ;;
    *) die "usage: drift-cosmic.sh mode light|dark" ;;
esac
