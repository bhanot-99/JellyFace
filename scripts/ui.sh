#!/usr/bin/env bash
# jellyface ui drift|classic|status: choose JellyFace's interface. Drift is the new one (shell/drift,
# docs/NEW-UI-PLAN.md); Classic is the original and the default. Switching restarts the shell.
# Drift adds its own COSMIC shortcuts (config/drift-shortcuts.ron; Super+Space takes over COSMIC's keyboard-layout
# switch, Super+W COSMIC's workspace overview) and `ui classic` removes exactly those again. The shortcut file is tracked, so `revert-system` restores it.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SC="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"

# shortcuts add|remove: Drift's lines are the ones that call `jellyface ipc drift`; your own shortcuts are never touched
# (a key you already bound yourself keeps your binding)
shortcuts() {
    sys_track "$SC"
    mkdir -p "$(dirname "$SC")"
    python3 -I - "$SC" "$JF_ROOT/config/drift-shortcuts.ron" "$JF_ROOT" "$1" <<'PY'
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
lines = [l for l in lines if "ipc drift " not in l]
if action == "add":
    binding = r"\(modifiers:\[[^\]]*\](?:,key:\"[^\"]*\")?\)"
    have = {re.findall(binding, re.sub(r"\s+", "", l))[0] for l in lines if re.findall(binding, re.sub(r"\s+", "", l))}
    lines += [l for l in ours if re.findall(binding, re.sub(r"\s+", "", l))[0] not in have]
tmp = path + ".tmp"
open(tmp, "w").write("{\n" + "".join(f"    {l},\n" for l in lines) + "}\n")
os.replace(tmp, path)
PY
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

case "${1:-status}" in
    drift)
        mkdir -p "$(dirname "$JF_UI_FILE")"
        [ -e "$JF_CONFIG_DIR/drift.json" ] || cp "$JF_ROOT/config/drift.json" "$JF_CONFIG_DIR/drift.json"
        printf 'drift\n' > "$JF_UI_FILE"
        shortcuts add
        log "interface: Drift (Super+Space command bar, Super+C Control Center, Super+E window hints, Super+W or Super+D desks, Super+P appearance, Super+Shift+/ shortcuts)"
        restart_shell Drift ;;
    classic)
        printf 'classic\n' > "$JF_UI_FILE" 2>/dev/null || true
        shortcuts remove
        "$JF_ROOT/scripts/drift-cosmic.sh" gaps restore || warn "could not restore COSMIC's window gaps"
        log "interface: Classic"
        restart_shell Classic ;;
    status)
        log "interface: $(jf_ui)" ;;
    *)
        die "usage: jellyface ui drift|classic|status" ;;
esac
