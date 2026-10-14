#!/usr/bin/env bash
# Collect everything the greeter shows (colours, wallpaper, profile picture, username) into one data directory.
# No root needed; `jellyface greeter install` copies this directory to /var/lib/jellyface-greeter.
# usage: stage.sh [DATA_DIR]      (default: $JF_ROOT/.greeter-data)
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$here/.greeter-data}"
mkdir -p "$out"

state="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json"
[ -f "$state" ] && cp "$state" "$out/scheme.json"

wp="$(python3 -I - "$here/scripts" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import theme
kind, path = theme.current_wallpaper()
print(path if kind == "image" else "")
PY
)" || wp=""
[ -n "$wp" ] && [ -f "$wp" ] && cp "$wp" "$out/bg.jpg"

face=""
for f in "$HOME/.face" "/var/lib/AccountsService/icons/$USER"; do [ -f "$f" ] && { face="$f"; break; }; done
[ -n "$face" ] && cp "$face" "$out/face.png"

printf '{"user": "%s", "session": "start-cosmic"}\n' "$USER" > "$out/greeter.json"
chmod -R a+rX "$out"
echo "$out"
