# Shared helpers for JellyFace scripts. Source this file, don't run it.
JF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[ -f "$JF_ROOT/.env.local" ] && . "$JF_ROOT/.env.local"

JF_CONTAINER="${JF_CONTAINER:-jellyface}"   # distrobox container that runs the shell
JF_SHELL="$JF_ROOT/shell"                   # patched Jellyface shell (QML)
JF_BUILD="$JF_ROOT/.build"                  # cmake build tree (regenerable)
JF_INSTALL="$JF_ROOT/.install"              # built QML plugin + version binary (regenerable)
JF_BACKUPS="${JF_BACKUPS:-$JF_ROOT/backups}"
# Anchored process patterns: they match only the processes JellyFace starts, never an unrelated command line
# that merely contains the same text (e.g. a grep, an editor, or a terminal running this very command).
JF_QS_RE="^quickshell -p ${JF_SHELL}\$"
JF_WSD_RE="^${JF_SHELL}/\\.\\./helpers/cosmic-ws/wsd\$"
JF_WIND_RE="^${JF_SHELL}/\\.\\./helpers/cosmic-windows/wind\$"
JF_SUP_RE="^((/usr)?/bin/)?bash ${JF_ROOT}/scripts/run\\.sh"
# Long-running programs the shell starts inside the container. Quickshell does not stop them when it is terminated or
# crashes, so they outlived every restart (reparented to the container's conmon) and piled up: one more clipboard
# watcher per restart, each recording every copy again.
JF_ORPHAN_RE="^(/usr)?(/s?bin/)?wl-paste --watch python3 -I ${JF_SHELL}/\\.\\./scripts/clipboard-store\\.py add\$|^(/usr)?(/s?bin/)?nmcli monitor\$"
JF_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jellyface"
JF_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/jellyface"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# Which interface the shell shows: "drift" or "classic" (the default). `jellyface ui` sets it.
JF_UI_FILE="$JF_CONFIG_DIR/ui"
jf_ui() { [ "$(tr -d '[:space:]' < "$JF_UI_FILE" 2>/dev/null)" = drift ] && echo drift || echo classic; }

log()  { printf '\033[1;35m[jellyface]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[jellyface] warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[jellyface] error:\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found. $2"; }

container_exists() { distrobox list 2>/dev/null | awk -F'|' 'NR>1{gsub(/ /,"",$2);print $2}' | grep -qx "$JF_CONTAINER"; }

# Run a bash snippet inside the container: in_container '<script>' [args...]
in_container() { local s="$1"; shift; distrobox enter "$JF_CONTAINER" -- bash -c "$s" _ "$@"; }

# Back up a file or directory into backups/ (never overwrites, never deletes anything)
backup() {
    local src="$1"
    [ -e "$src" ] || return 0
    mkdir -p "$JF_BACKUPS"
    local dest
    dest="$JF_BACKUPS/$(basename "$src").$(date +%Y%m%d-%H%M%S)"
    cp -a "$src" "$dest"
    log "backed up $src -> $dest"
}

# jf_rotate FILE [MAX_BYTES]: keep one previous generation, rotating by copy-and-truncate so a process that still has the
# file open for appending (the shell's stdout) keeps writing into the live file.
jf_rotate() {
    local f="$1" max="${2:-5242880}"
    [ -f "$f" ] && [ "$(stat -c %s "$f" 2>/dev/null || echo 0)" -gt "$max" ] && cp -f "$f" "$f.1" && : > "$f"
    return 0
}

# Quote a path for an Exec= line: systemd (ExecStart=) and the desktop-entry spec (Exec=) both split on spaces.
systemd_quote() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//%/%%}"; s="${s//\$/\$\$}"; printf '"%s"' "$s"; }
desktop_quote() { local s="$1"; s="${s//\\/\\\\\\\\}"; s="${s//\"/\\\\\"}"; s="${s//\`/\\\\\`}"; s="${s//\$/\\\\\$}"; printf '"%s"' "$s"; }

# --- tracked system changes -------------------------------------------------------------------------------------
# Every file JellyFace changes outside its own folder (COSMIC settings, user services, ...) is recorded here together
# with a copy of what was there before, so `jellyface revert-system` can put everything back exactly.
JF_MANIFEST="${XDG_STATE_HOME:-$HOME/.local/state}/jellyface/system-manifest.tsv"

# sys_track <path>: call BEFORE modifying/creating <path> (a file or a directory)
sys_track() {
    local path="$1" dest="(new)"
    mkdir -p "$(dirname "$JF_MANIFEST")"
    # already tracked once -> keep the first (original) version only (whole first column, not a substring match)
    if awk -F'\t' -v p="$path" '$1==p{f=1} END{exit !f}' "$JF_MANIFEST" 2>/dev/null; then return 0; fi
    if [ -e "$path" ]; then
        dest="$JF_BACKUPS/system/$(date +%Y%m%d-%H%M%S)$(echo "$path" | tr '/' '_')"
        mkdir -p "$JF_BACKUPS/system"
        cp -a "$path" "$dest"
    fi
    printf '%s\t%s\n' "$path" "$dest" >> "$JF_MANIFEST"
}

# cosmic_entries add|remove <Panel|Dock>: edit COSMIC's list of panels without touching the other entry (the dock and the
# top-panel scripts used to overwrite the whole list, undoing each other).
cosmic_entries() {
    local f="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel/v1/entries"
    sys_track "$f"; mkdir -p "$(dirname "$f")"
    python3 -I - "$f" "$1" "$2" <<'PY'
import json, os, sys
path, action, name = sys.argv[1:4]
try:
    items = json.load(open(path))
    if not isinstance(items, list):
        raise ValueError
except Exception:
    items = ["Panel", "Dock"]          # COSMIC's default
if action == "add" and name not in items:
    items.append(name)
elif action == "remove":
    items = [i for i in items if i != name]
order = ["Panel", "Dock"]
items.sort(key=lambda i: order.index(i) if i in order else len(order))
tmp = path + ".tmp"
with open(tmp, "w") as out:
    out.write(json.dumps(items, separators=(",", ":")))
os.replace(tmp, path)
PY
}

# ws_ready: true once the compositor answers ext-workspace-v1 requests. wsd streams forever, so read just its first
# line (a plain `$(timeout 3 wsd)` always burns the whole 3 seconds, which was a fixed delay on every start).
ws_ready() {
    local fd line=""
    exec {fd}< <(timeout 3 "$JF_ROOT/helpers/cosmic-ws/wsd" </dev/null 2>/dev/null)
    read -r -t 3 -u "$fd" line
    exec {fd}<&-
    [[ "$line" == *'"ws"'* ]]
}

# reap_orphans: stop those programs once their shell is gone. Only orphans inside the container are touched (their
# parent is no longer a quickshell; they were reparented to conmon or the user's systemd): the running shell's own
# children, and anything on the host, keep running.
reap_orphans() {
    local p pp host_ns
    host_ns="$(readlink /proc/self/ns/mnt)"
    for p in $(pgrep -f "$JF_ORPHAN_RE"); do
        [ "$(readlink "/proc/$p/ns/mnt" 2>/dev/null)" != "$host_ns" ] || continue
        pp="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
        [ "$(cat "/proc/$pp/comm" 2>/dev/null)" = quickshell ] || kill "$p" 2>/dev/null
    done
    return 0
}

# --- notifications -----------------------------------------------------------------------------------------------
# COSMIC's own cosmic-notifications owns org.freedesktop.Notifications, so the shell's notification server could never
# register and its panel stayed empty. While JellyFace runs, the shell owns the name; cosmic-notifications is only asked
# to let go of it (COSMIC restarts it by itself) and is restarted again when JellyFace stops.
JF_NOTIF_NAME=org.freedesktop.Notifications
notif_owner_pid() { busctl --user status "$JF_NOTIF_NAME" 2>/dev/null | sed -n 's/^PID=//p'; }

# --- lock screen safety ------------------------------------------------------------------------------------------
# While JellyFace's lock screen holds the session lock, the shell keeps this flag file (modules/lock/Lock.qml).
# If the shell dies while locked (a crash, a restart, the service being stopped), COSMIC keeps the session locked - as
# it must - but nothing is drawn to type the password into: no apps, no shortcuts, only a hard reboot helped.
# COSMIC lets a new locker replace a dead one, so we hand over to COSMIC's own lock screen right away.
JF_LOCK_FLAG="${XDG_RUNTIME_DIR:-/tmp}/jellyface-locked"
# true while the running shell's lock screen is up (the flag alone could be stale; when the shell cannot be asked,
# assume locked: the safe answer)
locked_by_shell() {
    [ -e "$JF_LOCK_FLAG" ] && pgrep -f "$JF_QS_RE" >/dev/null || return 1
    [ "$(timeout 5 "$JF_ROOT/bin/jellyface" ipc lock isLocked 2>/dev/null)" != false ]
}
lock_handover() {
    [ -e "$JF_LOCK_FLAG" ] || return 0
    # Called when the shell is being stopped or has died. Make sure it is really gone (it may take a few seconds to exit
    # inside the container), then hand over; COSMIC refuses a second locker while the first one is alive.
    local _
    for _ in $(seq 1 25); do pgrep -f "$JF_QS_RE" >/dev/null || break; sleep 0.2; done
    pkill -9 -f "$JF_QS_RE" 2>/dev/null && sleep 1
    rm -f "$JF_LOCK_FLAG"
    # a systemd service has no login session of its own: name the user's graphical session explicitly
    local sid; sid="$(loginctl show-user "$(id -un)" -p Display --value 2>/dev/null)"
    if loginctl lock-session ${sid:+"$sid"} 2>/dev/null || loginctl lock-sessions 2>/dev/null; then
        warn "the shell stopped while the screen was locked; COSMIC's lock screen took over"
    fi
}
