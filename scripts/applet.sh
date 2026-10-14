#!/usr/bin/env bash
# The JellyFace menu as a native COSMIC panel applet.
#   applet.sh install        build the applet and register it with COSMIC (it then shows in Settings -> Panel -> applets)
#   applet.sh panel-add      also put it in your COSMIC panel (right side, first position)
#   applet.sh panel-remove   take it out of the panel again
#   applet.sh remove         unregister it (also removes it from the panel)
# Everything is user-level and tracked: `jellyface revert-system` undoes it.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

ID="com.jellyface.Applet"
BIN="$JF_ROOT/native/jellyface-applet/target/release/jellyface-applet"
DESKTOP="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$ID.desktop"
PANEL="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/v1"

edit_panel() {   # edit_panel add|remove
    [ -f "$PANEL/plugins_wings" ] || die "no panel config at $PANEL"
    sys_track "$PANEL"
    python3 -I - "$PANEL/plugins_wings" "$ID" "$1" <<'PY'
import re, sys
path, ident, action = sys.argv[1:4]
s = open(path).read()
m = re.fullmatch(r"\s*Some\(\(\s*(\[.*?\])\s*,\s*(\[.*?\])\s*,?\s*\)\)\s*", s, re.S)
if not m:
    sys.exit("unexpected panel config format; left untouched")
left, right = m.group(1), m.group(2)
items = re.findall(r'"([^"]+)"', right)
if action == "add" and ident not in items:
    items.insert(0, ident)
elif action == "remove":
    items = [i for i in items if i != ident]
else:
    sys.exit(0)
new = "Some((" + left + ", [" + ", ".join(f'"{i}"' for i in items) + "]))"
tmp = path + ".tmp"
open(tmp, "w").write(new)
import os
os.replace(tmp, path)
PY
}

case "${1:-}" in
    install)
        [ -x "$BIN" ] || "$JF_ROOT/native/build.sh" || die "applet build failed"
        sys_track "$DESKTOP"
        mkdir -p "$(dirname "$DESKTOP")"
        cat > "$DESKTOP" <<DESKTOPEOF
[Desktop Entry]
Name=JellyFace
Comment=JellyFace menu: launcher, dashboard, lock screen and wallpaper theme
Type=Application
Exec=env JELLYFACE_ROOT=$JF_ROOT $BIN
Terminal=false
Categories=COSMIC;
Keywords=COSMIC;Applet;JellyFace;
Icon=$JF_ROOT/assets/jellyface-app.svg
StartupNotify=true
NoDisplay=true
X-CosmicApplet=true
X-CosmicHoverPopup=End
X-OverflowPriority=10
DESKTOPEOF
        log "applet registered ($DESKTOP). Add it with: jellyface applet panel-add (or in COSMIC Settings -> Desktop -> Panel)"
        ;;
    panel-add)    [ -f "$DESKTOP" ] || die "run: jellyface applet install"; edit_panel add && log "applet added to your COSMIC panel";;
    panel-remove) edit_panel remove && log "applet removed from your COSMIC panel";;
    remove)       edit_panel remove; [ -e "$DESKTOP" ] && rm -- "$DESKTOP" && log "applet unregistered";;
    *) echo "usage: applet.sh install|panel-add|panel-remove|remove" >&2; exit 2 ;;
esac
