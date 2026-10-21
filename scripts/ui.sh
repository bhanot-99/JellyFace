#!/usr/bin/env bash
# jellyface ui quill|classic|toggle|status (and `jellyface switch` = toggle): choose JellyFace's interface. Quill UI is
# the new one (shell/quill, docs/NEW-UI-PLAN.md); Classic is the original and the default. Switching restarts the shell.
# Quill adds its own COSMIC shortcuts (config/quill-shortcuts.ron; Super+Space takes over COSMIC's keyboard-layout
# switch, Super+W COSMIC's workspace overview) and `ui classic` removes exactly those again. The shortcut file is tracked, so `revert-system` restores it.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SC="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"

# shortcuts add|remove: Quill's lines are the ones that call `jellyface ipc quill`; your own shortcuts are never touched
# (a key you already bound yourself keeps your binding)
shortcuts() {
    sys_track "$SC"
    mkdir -p "$(dirname "$SC")"
    python3 -I - "$SC" "$JF_ROOT/config/quill-shortcuts.ron" "$JF_ROOT" "$1" <<'PY'
import os, re, sys
path, tmpl, root, action = sys.argv[1:5]
ours = [l.strip().rstrip(",") for l in open(tmpl).read().replace("@JF_ROOT@", root).splitlines() if "Spawn(" in l]
try:
    cur = open(path).read()
except OSError:
    cur = "{\n}\n"
m = re.fullmatch(r"\s*\{(.*)\}\s*", cur, re.S)
if not m:
    sys.exit(f"warning: {path} has an unexpected format; shortcuts left alone")
lines = [l.strip().rstrip(",") for l in m.group(1).splitlines() if l.strip().rstrip(",")]
lines = [l for l in lines if "ipc quill " not in l and "ipc drift " not in l]   # (drift: Quill's development name)
if action == "add":
    binding = r"\(modifiers:\[[^\]]*\](?:,key:\"[^\"]*\")?\)"
    have = {re.findall(binding, re.sub(r"\s+", "", l))[0] for l in lines if re.findall(binding, re.sub(r"\s+", "", l))}
    lines += [l for l in ours if re.findall(binding, re.sub(r"\s+", "", l))[0] not in have]
tmp = path + ".tmp"
open(tmp, "w").write("{\n" + "".join(f"    {l},\n" for l in lines) + "}\n")
os.replace(tmp, path)
PY
}

# the login screen follows the interface (greeter/QuillScreen.qml or Classic's); nothing to do unless it is installed
sync_greeter() {
    [ -w /var/lib/jellyface-greeter/data ] && "$JF_ROOT/greeter/stage.sh" /var/lib/jellyface-greeter/data >/dev/null 2>&1 || true
}

restart_shell() {
    if ! pgrep -f "$JF_QS_RE" >/dev/null; then
        log "the shell is not running; it will start in $1 next time"
        return
    fi
    if locked_by_shell; then
        warn "the screen is locked; $1 takes effect at the next restart"
        return
    fi
    "$JF_ROOT/bin/jellyface" restart
}

want="${1:-status}"
if [ "$want" = toggle ]; then
    want=$([ "$(jf_ui)" = quill ] && echo classic || echo quill)
fi

case "$want" in
    quill)
        mkdir -p "$(dirname "$JF_UI_FILE")"
        [ -e "$JF_CONFIG_DIR/quill.json" ] || cp "$JF_ROOT/config/quill.json" "$JF_CONFIG_DIR/quill.json"
        printf 'quill\n' > "$JF_UI_FILE"
        shortcuts add
        sync_greeter
        log "interface: Quill UI (Super+Space command bar, Super+C Control Center, Super+E window hints, Super+W or Super+D desks, Super+P appearance, Super+Shift+/ shortcuts)"
        restart_shell "Quill UI" ;;
    classic)
        printf 'classic\n' > "$JF_UI_FILE" 2>/dev/null || true
        shortcuts remove
        sync_greeter
        "$JF_ROOT/scripts/quill-cosmic.sh" gaps restore || warn "could not restore COSMIC's window gaps"
        log "interface: Classic"
        restart_shell Classic ;;
    status)
        log "interface: $([ "$(jf_ui)" = quill ] && echo "Quill UI" || echo Classic)  (jellyface switch to change)" ;;
    *)
        die "usage: jellyface ui quill|classic|toggle|status   (or: jellyface switch)" ;;
esac
