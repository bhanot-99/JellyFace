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
cleanup() {   # stop our own children and the shell, never anything else
    rm -f "$PIDFILE"
    pkill -P $$ 2>/dev/null
    pkill -f "$JF_QS_RE" 2>/dev/null
    return 0
}
trap cleanup EXIT
trap 'exit 0' TERM INT HUP

# --- preflight ---------------------------------------------------------------
container_exists || die "container '$JF_CONTAINER' does not exist. Run: jellyface install"
[ -x "$JF_ROOT/helpers/cosmic-ws/wsd" ] || die "workspace helper not built. Run: jellyface build"
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

# The lock screen's PAM stack checks the typed password against the HOST account; it needs the absolute path to
# this checkout, so (re)generate it from the template on every start.
sed "s#@JF_ROOT@#$JF_ROOT#g" "$JF_ROOT/config/pam-passwd.tmpl" > "$JF_SHELL/assets/pam.d/passwd"

# --- wait for the desktop session (matters when started from autostart at login) ----
SOCK="$RUNTIME/${WAYLAND_DISPLAY:-wayland-1}"
for _ in $(seq 1 90); do [ -S "$SOCK" ] && break; sleep 1; done
[ -S "$SOCK" ] || die "no Wayland socket at $SOCK after 90s; is a COSMIC session running?"
for _ in $(seq 1 60); do   # the compositor must also answer protocol requests (not just own the socket)
    out="$(timeout 3 "$JF_ROOT/helpers/cosmic-ws/wsd" </dev/null 2>/dev/null || true)"
    [[ "$out" == *'"ws"'* ]] && break
    sleep 1
done

# Icon theme of the host desktop (COSMIC), so tray and app icons match the rest of the system
ICON_THEME="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
ICON_THEME="${ICON_THEME:-Cosmic}"

# Wallpaper-driven theme: re-applies the best matching palette whenever the COSMIC wallpaper changes
# (stops with the supervisor; `jellyface theme auto off` keeps one palette). fd 9 is closed so it can never hold the lock.
mkdir -p "$JF_ROOT/logs"
python3 -I "$JF_ROOT/scripts/theme.py" watch >>"$JF_ROOT/logs/theme.log" 2>&1 9>&- &

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
    # fd 9 (the lock) is closed for the child so a leftover child can never block the next start
    in_container '
    export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/host/run/dbus/system_bus_socket
    export QML_IMPORT_PATH="$1/qml" QML2_IMPORT_PATH="$1/qml"
    # The container only ships Adwaita/hicolor: also search the host icon themes, .desktop files and Flatpak exports
    export XDG_DATA_DIRS="$XDG_DATA_DIRS:/run/host/usr/share:/run/host/usr/local/share:/run/host/var/lib/flatpak/exports/share"
    export QS_ICON_THEME="$4"
    unset QT_QPA_PLATFORMTHEME
    if [ "$3" -gt 0 ]; then timeout "$3" quickshell -p "$2"; else quickshell -p "$2"; fi 2>&1 | sed -u "s/\x1b\[[0-9;]*m//g"
    exit "${PIPESTATUS[0]}"
    ' "$JF_INSTALL" "$JF_SHELL" "$remaining" "$ICON_THEME" 9>&-
    rc=$?
    [ "$rc" -eq 124 ] && { log "timeout reached, stopping"; break; }
    [ "$rc" -eq 0 ]   && { log "shell exited normally"; break; }

    # crashed: restart, but give up if it keeps dying immediately (avoids a runaway loop)
    if [ $((SECONDS - started)) -lt 20 ]; then fast_fails=$((fast_fails + 1)); else fast_fails=0; fi
    if [ "$fast_fails" -ge 5 ]; then die "shell crashed 5 times in a row right after starting; giving up (see logs/jellyface.log)"; fi
    warn "shell exited with code $rc; restarting in $((fast_fails * 3 + 2))s"
    sleep $((fast_fails * 3 + 2))
done
