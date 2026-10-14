#!/usr/bin/env bash
# Switches COSMIC's wallpaper to the next image of a folder (JellyFace's theme follows it: scripts/theme.py watches the wallpaper).
# usage: wallpaper-cycle.sh FOLDER [shuffle|order]
# Your COSMIC background settings are copied to backups/ once, before the first change.
set -euo pipefail
JF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
folder="${1:-$HOME/Pictures}"; folder="${folder/#\~/$HOME}"
mode="${2:-shuffle}"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicBackground/v1/all"
[ -f "$cfg" ] || { echo "COSMIC background config not found: $cfg" >&2; exit 1; }
[ -d "$folder" ] || { echo "not a folder: $folder" >&2; exit 1; }

mkdir -p "$JF_ROOT/backups"
[ -e "$JF_ROOT/backups/CosmicBackground-all.original" ] || cp -a "$cfg" "$JF_ROOT/backups/CosmicBackground-all.original"

python3 -I - "$cfg" "$folder" "$mode" <<'PY'
import os, random, re, sys
cfg, folder, mode = sys.argv[1:4]
text = open(cfg, encoding="utf-8").read()
m = re.search(r'source:\s*Path\("([^"]+)"\)', text)
current = m.group(1) if m else ""
exts = (".jpg", ".jpeg", ".png", ".webp", ".avif")
files = sorted(os.path.join(folder, f) for f in os.listdir(folder)
               if f.lower().endswith(exts) and not f.startswith(".") and os.path.isfile(os.path.join(folder, f)))
if not files:
    sys.exit("no images in " + folder)
others = [f for f in files if f != current] or files
if mode == "order" and current in files:
    nxt = files[(files.index(current) + 1) % len(files)]
else:
    nxt = random.choice(others)
new = re.sub(r'source:\s*Path\("[^"]*"\)', lambda _: 'source: Path("%s")' % nxt, text, count=1)
if new == text:
    sys.exit("could not find the wallpaper in " + cfg)
open(cfg, "w", encoding="utf-8").write(new)
print(nxt)
PY
