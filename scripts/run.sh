#!/usr/bin/env bash
# Supervisor: runs the shell inside the container and restarts it if it crashes.
# Usage: run.sh [seconds]   (0 or omitted = run until stopped; N = stop after N seconds, a safety net for testing)
set -uo pipefail
. "$(dirname "$0")/lib.sh"

T="${1:-0}"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
LOCK="$RUNTIME/jellyface.lock"
PIDFILE="$RUNTIME/jellyface.pid"

# --- single instance ---------------------------------------------------------
exec 9>"$LOCK"
flock -n 9 || { log "already running"; exit 0; }
echo $$ > "$PIDFILE"

child=0 guard=0
# set while COSMIC's notification daemon has been displaced; kept across a restart, so the final stop still hands back
TOOK="$RUNTIME/jellyface.took-notifications"
RESTARTING="$RUNTIME/jellyface.restarting"
cleanup() {   # stop our own children and the shell, never anything else
    rm -f "$PIDFILE"
    [ "$guard" -gt 0 ] && { pkill -P "$guard" 2>/dev/null; kill "$guard" 2>/dev/null; }
    [ "$child" -gt 0 ] && kill "$child" 2>/dev/null
    pkill -P $$ 2>/dev/null
    pkill -f "$JF_QS_RE" 2>/dev/null
    # give the notification name back to COSMIC (its session restarts the daemon, which then registers again). COSMIC
    # restarts its top panel together with the daemon, so not during `jellyface restart`: the new shell takes the
    # name straight back.
    if [ -e "$RESTARTING" ] && [ $(( $(date +%s) - $(stat -c %Y "$RESTARTING") )) -lt 60 ]; then :
    elif [ -e "$TOOK" ]; then rm -f "$TOOK"; pkill -x cosmic-notifica 2>/dev/null; fi
    rm -f "$RESTARTING"
    lock_handover
    return 0
}
trap cleanup EXIT
trap 'exit 0' TERM INT HUP

# --- warm up the container in the background -----------------------------------------------------
# After a reboot the container is stopped and `distrobox enter` would have to start it first (several seconds).
# Starting it now overlaps that with everything below.
( command -v podman >/dev/null && podman container exists "$JF_CONTAINER" 2>/dev/null && podman start "$JF_CONTAINER" >/dev/null 2>&1 ) 9>&- &

# --- leftovers ---------------------------------------------------------------
# We hold the single-instance lock, so any shell/helper of this checkout still running is an orphan of a supervisor
# that was killed hard (e.g. SIGKILL): clear it before starting a fresh one.
if pgrep -f "$JF_QS_RE|$JF_WSD_RE|$JF_WIND_RE" >/dev/null; then
    pkill -f "$JF_QS_RE" 2>/dev/null; pkill -f "$JF_WSD_RE" 2>/dev/null; pkill -f "$JF_WIND_RE" 2>/dev/null
    for _ in $(seq 1 40); do pgrep -f "$JF_QS_RE" >/dev/null || break; sleep 0.1; done
fi

# --- preflight ---------------------------------------------------------------
container_exists || die "container '$JF_CONTAINER' does not exist. Run: jellyface install"
[ -x "$JF_ROOT/helpers/cosmic-ws/wsd" ] && [ -x "$JF_ROOT/helpers/cosmic-windows/wind" ] || die "COSMIC helpers not built. Run: jellyface build"
[ -d "$JF_INSTALL/qml" ] || die "shell plugin not built. Run: jellyface build"

# A broken config file must never keep the shell from starting: back it up and restore the default.
validate_json() {
    local f="$1" default="$2"
    [ -e "$f" ] || { mkdir -p "$(dirname "$f")"; cp "$default" "$f"; return; }
    python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null && return
    warn "$f is not valid JSON; restoring the default"
    backup "$f"; cp "$default" "$f"
}
validate_json "$JF_CONFIG_DIR/shell.json"        "$JF_ROOT/config/shell.json"
validate_json "$JF_CONFIG_DIR/shell-tokens.json" "$JF_ROOT/config/shell-tokens.json"
validate_json "$JF_STATE_DIR/scheme.json"        "$JF_ROOT/config/scheme.json"
validate_json "$JF_CONFIG_DIR/dock.json"         "$JF_ROOT/config/dock.json"
validate_json "$JF_CONFIG_DIR/desktop.json"      "$JF_ROOT/config/desktop.json"

# The lock screen's PAM stack checks the typed password against the HOST account; it needs the absolute path to
# this checkout, so (re)generate it from the template (only when it changed, to leave the file alone otherwise).
pam_new="$(sed "s#@JF_ROOT@#$JF_ROOT#g" "$JF_ROOT/config/pam-passwd.tmpl")"
[ "$(cat "$JF_SHELL/assets/pam.d/passwd" 2>/dev/null)" = "$pam_new" ] || printf '%s\n' "$pam_new" > "$JF_SHELL/assets/pam.d/passwd"

# --- wait for the desktop session (matters at login) ------------------------------------------------
SOCK="$RUNTIME/${WAYLAND_DISPLAY:-wayland-1}"
for _ in $(seq 1 450); do [ -S "$SOCK" ] && break; sleep 0.2; done
[ -S "$SOCK" ] || die "no Wayland socket at $SOCK after 90s; is a COSMIC session running?"
for _ in $(seq 1 100); do   # the compositor must also answer protocol requests (not just own the socket)
    ws_ready && break
    sleep 0.3
done

# Icon theme of the host desktop (COSMIC), so tray and app icons match the rest of the system
ICON_THEME="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
ICON_THEME="${ICON_THEME:-Cosmic}"

# Make sure the shell (not cosmic-notifications) owns the notification name, now and whenever it changes hands
# (a shell restart or an in-place reload releases it for a moment, and COSMIC's idle daemon could slip in).
# COSMIC's session restarts the daemon whenever it is stopped, which is also how it comes back after JellyFace stops.
notif_check() {
    local pid; pid="$(notif_owner_pid)"
    # (comm is cut to 15 characters by the kernel, so "cosmic-notifications" shows up as "cosmic-notifica")
    [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = cosmic-notifica ] || return 0
    pgrep -f "$JF_QS_RE" >/dev/null || return 0     # never take it away unless our shell is there to take over
    kill "$pid" 2>/dev/null && : > "$TOOK"
}
notif_guard() {
    local line
    sleep 3; notif_check
    dbus-monitor --session "type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged',arg0='$JF_NOTIF_NAME'" 2>/dev/null |
        while read -r line; do
            case "$line" in *NameOwnerChanged*) ( sleep 1.5; notif_check ) ;; esac
        done
}

mkdir -p "$JF_ROOT/logs"
# the logs used to be rotated only when the shell started: a session that runs for weeks grew them without limit
( while sleep 600; do jf_rotate "$JF_ROOT/logs/jellyface.log"; jf_rotate "$JF_ROOT/logs/theme.log" 1048576; done ) 9>&- >/dev/null 2>&1 &
watcher=0
notif_guard 9>&- >/dev/null 2>&1 &
guard=$!
# --- supervise ---------------------------------------------------------------
end=$((SECONDS + T))
fast_fails=0
while :; do
    remaining=0
    if [ "$T" -gt 0 ]; then
        remaining=$((end - SECONDS))
        [ "$remaining" -le 0 ] && { log "timeout reached, stopping"; break; }
    fi
    started=$SECONDS
    # fd 9 (the lock) is closed for the child so a leftover child can never block the next start.
    # It runs in the background and we `wait`: bash only runs its TERM trap between commands, so a foreground child
    # made `systemctl stop`/logout wait out the whole stop timeout before the shell was told to quit.
    in_container '
    export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/host/run/dbus/system_bus_socket
    export QML_IMPORT_PATH="$1/qml" QML2_IMPORT_PATH="$1/qml"
    # The container only ships Adwaita/hicolor: also search the host icon themes, .desktop files and Flatpak exports
    export XDG_DATA_DIRS="$XDG_DATA_DIRS:/run/host/usr/share:/run/host/usr/local/share:/run/host/var/lib/flatpak/exports/share"
    export QS_ICON_THEME="$4"
    unset QT_QPA_PLATFORMTHEME
    export PATH="$5:$PATH"   # notify-send shim (neither the host nor the container ships libnotify)
    if [ "$3" -gt 0 ]; then timeout "$3" quickshell -p "$2"; else quickshell -p "$2"; fi 2>&1 | sed -u "s/\x1b\[[0-9;]*m//g"
    exit "${PIPESTATUS[0]}"
    ' "$JF_INSTALL" "$JF_SHELL" "$remaining" "$ICON_THEME" "$JF_ROOT/scripts/shims" 9>&- &
    child=$!

    # wallpaper theming watcher: started after the shell so it never competes with it for CPU at login
    if [ "$watcher" -eq 0 ] || ! kill -0 "$watcher" 2>/dev/null; then
        nice -n 10 python3 -I "$JF_ROOT/scripts/theme.py" watch >>"$JF_ROOT/logs/theme.log" 2>&1 9>&- &
        watcher=$!
    fi

    wait "$child"
    rc=$?
    child=0
    lock_handover     # died while locked: COSMIC's lock screen takes over at once, the restarted shell does not re-lock
    [ "$rc" -eq 124 ] && { log "timeout reached, stopping"; break; }
    [ "$rc" -eq 0 ]   && { log "shell exited normally"; break; }

    # crashed: restart. A shell that ran for a while before dying (for example the compositor dropping it when the
    # lock screen is unlocked) comes straight back; one that keeps dying immediately backs off and eventually gives up.
    if [ $((SECONDS - started)) -lt 20 ]; then fast_fails=$((fast_fails + 1)); else fast_fails=0; fi
    if [ "$fast_fails" -ge 5 ]; then die "shell crashed 5 times in a row right after starting; giving up (see logs/jellyface.log)"; fi
    delay=0; [ "$fast_fails" -gt 0 ] && delay=$((fast_fails * 3 + 2))
    warn "shell exited with code $rc; restarting$([ "$delay" -gt 0 ] && echo " in ${delay}s")"
    [ "$delay" -gt 0 ] && sleep "$delay"
done
