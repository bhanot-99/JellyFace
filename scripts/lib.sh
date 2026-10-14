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
JF_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jellyface"
JF_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/jellyface"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

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

# --- tracked system changes -------------------------------------------------------------------------------------
# Every file JellyFace changes outside its own folder (COSMIC settings, user services, ...) is recorded here together
# with a copy of what was there before, so `jellyface revert-system` can put everything back exactly.
JF_MANIFEST="${XDG_STATE_HOME:-$HOME/.local/state}/jellyface/system-manifest.tsv"

# sys_track <path>: call BEFORE modifying/creating <path> (a file or a directory)
sys_track() {
    local path="$1" dest="(new)"
    mkdir -p "$(dirname "$JF_MANIFEST")"
    # already tracked once -> keep the first (original) version only
    if grep -qF "$path"$'\t' "$JF_MANIFEST" 2>/dev/null; then return 0; fi
    if [ -e "$path" ]; then
        dest="$JF_BACKUPS/system/$(date +%Y%m%d-%H%M%S)$(echo "$path" | tr '/' '_')"
        mkdir -p "$JF_BACKUPS/system"
        cp -a "$path" "$dest"
    fi
    printf '%s\t%s\n' "$path" "$dest" >> "$JF_MANIFEST"
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
