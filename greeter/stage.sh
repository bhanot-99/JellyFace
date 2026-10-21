#!/usr/bin/env bash
# Collect everything the greeter shows (colours, wallpaper, profile picture, username) into one data directory.
# No root needed; `jellyface greeter install` copies this directory to /var/lib/jellyface-greeter.
# usage: stage.sh [DATA_DIR]      (default: $JF_ROOT/.greeter-data)
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$here/.greeter-data}"
mkdir -p "$out"

state="${XDG_STATE_HOME:-$HOME/.local/state}/jellyface/scheme.json"
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

# the interface you chose (`jellyface ui`): Quill draws the login screen in its own look, with your theme and accent
. "$here/scripts/lib.sh"
python3 -I - "$out/greeter.json" "$USER" "$(jf_ui)" "$JF_CONFIG_DIR/quill.json" <<'PY'
import json, sys
out, user, ui, qpath = sys.argv[1:5]
try:
    q = json.load(open(qpath))
except (OSError, ValueError):
    q = {}
json.dump({"user": user, "session": "start-cosmic", "ui": ui,
           "quill": {"theme": q.get("theme", "light"), "accent": q.get("accent", "indigo")}}, open(out, "w"))
PY
cp "$here"/shell/quill/assets/fonts/Inter.ttf "$here"/shell/quill/assets/fonts/JetBrainsMono.ttf "$out/" 2>/dev/null || true

# Lock-screen extras: the no-notifications dino, the fetch logo, window manager name, and the last known weather
cp "$here"/shell/assets/google-sans-flex/*.ttf "$out/gsf.ttf" 2>/dev/null || true
cp "$here/shell/assets/dino.png" "$here/shell/assets/logo.svg" "$out/" 2>/dev/null || true
printf '{"wm": "%s"}\n' "$(basename "${XDG_CURRENT_DESKTOP:-COSMIC}" | cut -d: -f1)" > "$out/fetch.json"
# the weather is only fetched when the saved copy is older than 30 minutes (a wallpaper change re-stages everything, and
# every fetch tells a third party roughly where you are)
if [ -n "$(find "$out/weather.json" -mmin -30 2>/dev/null)" ]; then
    :
else
python3 -I - "$out/weather.json" <<'PY' || true
import json, sys, urllib.request
cfg = json.load(open(__import__("os").path.expanduser("~/.config/jellyface/shell.json")))
loc = cfg.get("services", {}).get("weatherLocation", "")
if "," not in loc:
    sys.exit(0)
lat, lon = [x.strip() for x in loc.split(",")]
url = ("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&daily=weather_code,temperature_2m_max,temperature_2m_min"
       "&current=temperature_2m,apparent_temperature,weather_code&timezone=auto&forecast_days=1" % (lat, lon))
j = json.load(urllib.request.urlopen(url, timeout=8))
json.dump({"loc": loc, "code": j["current"]["weather_code"], "temp": j["current"]["temperature_2m"],
           "feels": j["current"]["apparent_temperature"], "hi": j["daily"]["temperature_2m_max"][0],
           "lo": j["daily"]["temperature_2m_min"][0]}, open(sys.argv[1], "w"))
PY
fi
chmod -R a+rX "$out"
echo "$out"
