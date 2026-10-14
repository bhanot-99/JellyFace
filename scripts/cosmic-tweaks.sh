#!/usr/bin/env bash
# Optional: makes COSMIC's own top panel auto-hide and stop reserving space, so JellyFace's bar and
# dashboard are not covered; keeps the screen on while idle, so the lock screen stays visible instead of going black;
# adds JellyFace's shortcuts. Backs everything up first. Undo with: cosmic-tweaks.sh --revert
set -euo pipefail
. "$(dirname "$0")/lib.sh"

P="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/v1"
IDLE="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicIdle/v1"
IDLE_KEYS="screen_off_time suspend_on_ac_time suspend_on_battery_time"
[ -d "$P" ] || die "COSMIC panel config not found at $P"

if [ "${1:-}" = "--revert" ]; then
    # put back the user's own values (recorded before the first change); only fall back to COSMIC's defaults if unknown
    orig="$(awk -F'\t' -v p="$P" '$1==p{print $2}' "$JF_MANIFEST" 2>/dev/null | head -1)"
    for k in autohide exclusive_zone; do
        if [ -n "$orig" ] && [ -f "$orig/$k" ]; then cp "$orig/$k" "$P/$k"
        elif [ "$k" = autohide ]; then printf 'Never' > "$P/$k"
        else printf 'true' > "$P/$k"; fi
    done
    log "COSMIC panel restored to how it was before"
    # COSMIC's idle timers: the user's own values if there were any, otherwise COSMIC's defaults (no file)
    orig="$(awk -F'\t' -v p="$IDLE" '$1==p{print $2}' "$JF_MANIFEST" 2>/dev/null | head -1)"
    for k in $IDLE_KEYS; do
        if [ -n "$orig" ] && [ -f "$orig/$k" ]; then cp "$orig/$k" "$IDLE/$k"; else rm -f "$IDLE/$k"; fi
    done
    log "COSMIC screen-off and suspend timers restored"
    exit 0
fi
backup "$P"
sys_track "$P"
printf 'Always' > "$P/autohide"       # hide until the cursor touches the top edge
printf 'false'  > "$P/exclusive_zone" # don't reserve space while hidden
log "COSMIC top panel now auto-hides (it re-appears on hover at the top edge)"

# Always-on lock screen: COSMIC's idle daemon would turn the screen off (and suspend) a few minutes after JellyFace's
# idle lock, so the lock screen went black. Its timers are set to "never"; JellyFace still locks after 3 idle minutes
# (shell.json general.idle), and closing the lid still suspends.
mkdir -p "$IDLE"
backup "$IDLE"
sys_track "$IDLE"
for k in $IDLE_KEYS; do printf 'None' > "$IDLE/$k"; done
log "screen stays on while idle (COSMIC screen-off and idle suspend: never)"

# Super+L locks the screen with JellyFace's own lock screen (this replaces COSMIC's default Super+L = "focus window to the right"; COSMIC's own Super+Escape is untouched)
# Super+V clipboard history, Super+Shift+F focus mode and Super alone = JellyFace's JellyPanel (instead of COSMIC's
# launcher; Super+/ still opens that) come from the same template. Your own custom shortcuts are
# kept: only bindings for keys you have not used yet are added.
SC="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
sys_track "$SC"
mkdir -p "$(dirname "$SC")"
python3 -I - "$SC" "$JF_ROOT/config/cosmic-shortcuts.ron" "$JF_ROOT" <<'PY'
import os, re, sys
path, tmpl, root = sys.argv[1:4]
ours = [l.strip().rstrip(",") for l in open(tmpl).read().replace("@JF_ROOT@", root).splitlines() if "Spawn(" in l]
try:
    cur = open(path).read()
except OSError:
    cur = "{\n}\n"
m = re.fullmatch(r"\s*\{(.*)\}\s*", cur, re.S)
if not m:
    sys.exit(f"warning: {path} has an unexpected format; add the shortcuts from config/cosmic-shortcuts.ron yourself")
body = m.group(1).rstrip().rstrip(",")
binding = r"\(modifiers:\[[^\]]*\](?:,key:\"[^\"]*\")?\)"   # (modifiers:[Super],key:"l") or (modifiers:[Super]), spaces removed
have = set(re.findall(binding, re.sub(r"\s+", "", body)))
add = [l for l in ours if re.findall(binding, re.sub(r"\s+", "", l))[0] not in have]
if not add:
    print("shortcuts: already set (or the keys are taken by your own shortcuts)")
    sys.exit(0)
lines = ([body.strip()] if body.strip() else []) + add
tmp = path + ".tmp"
open(tmp, "w").write("{\n    " + ",\n    ".join(lines) + ",\n}\n")
os.replace(tmp, path)
print("shortcuts added: " + ", ".join(re.search(r"\((modifiers[^)]*)\)", l).group(1) for l in add))
PY
