#!/usr/bin/env bash
# Lid switch: lock with JellyFace's lock screen before the system suspends.
#
# COSMIC's own locker (cosmic-greeter) locks the session on every suspend. It is a native host process with a sleep-delay
# inhibitor, so it always won the race against the shell, which hears about the suspend later and through the container:
# closing the lid showed COSMIC's lock screen. Once JellyFace holds the session lock, COSMIC's locker stays out.
#
# So while this runs it holds logind's handle-lid-switch inhibitor (logind then leaves the lid to us). When the lid closes
# it locks, waits until the lock screen is up, and then does what logind would have done (the HandleLidSwitch* settings).
# The inhibitor ends with this process. If the shell is not running or cannot lock within ~3 s, the system suspends
# anyway and COSMIC's locker locks, as before: closing the lid never stops suspending the machine.
#
# Usage: lid.sh SUPERVISOR_PID   (started by run.sh; exits when the supervisor is gone)
set -uo pipefail
. "$(dirname "$0")/lib.sh"
JF="$JF_ROOT/bin/jellyface"

if [ "${1:-}" != --inhibited ]; then
    sup="${1:?usage: lid.sh SUPERVISOR_PID}"
    # no lid (a desktop), or no logind/UPower: nothing to do
    [ "$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower LidIsPresent 2>/dev/null)" = "b true" ] || exit 0
    exec systemd-inhibit --what=handle-lid-switch --who=JellyFace --mode=block \
        --why="Lock with JellyFace's lock screen before suspending" "$0" --inhibited "$sup"
fi
sup="$2"

prop() { busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "$1" 2>/dev/null | sed -E 's/^[a-z] //; s/"//g'; }

# the same choice logind makes: docked (or an external display), then on external power, then the default
lid_action() {
    if [ "$(prop Docked)" = true ]; then prop HandleLidSwitchDocked; return; fi
    local ext; ext="$(prop HandleLidSwitchExternalPower)"
    if [ "$(prop OnExternalPower)" = true ] && [ -n "$ext" ]; then echo "$ext"; return; fi
    prop HandleLidSwitch
}

jf_lock() {   # true once JellyFace's lock screen is up
    pgrep -f "$JF_QS_RE" >/dev/null || return 1
    timeout 3 "$JF" ipc lock lock >/dev/null 2>&1 || return 1
    local _
    for _ in $(seq 1 12); do
        [ "$(timeout 2 "$JF" ipc lock isSecure 2>/dev/null)" = true ] && return 0
        sleep 0.25
    done
    return 1
}

on_close() {
    local action; action="$(lid_action)"
    case "$action" in
        ignore|"") ;;
        lock) jf_lock || warn "lid closed: JellyFace could not lock" ;;
        poweroff|reboot|halt|kexec) systemctl "$action" ;;
        *)  # suspend, hibernate, hybrid-sleep, suspend-then-hibernate (and anything newer: suspend)
            jf_lock || warn "lid closed: JellyFace could not lock in time; COSMIC's lock screen takes over"
            case "$action" in suspend|hibernate|hybrid-sleep|suspend-then-hibernate) ;; *) action=suspend ;; esac
            systemctl "$action" || warn "lid closed: systemctl $action failed" ;;
    esac
}

mon=0
trap '[ "$mon" -gt 0 ] && kill "$mon" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP
while kill -0 "$sup" 2>/dev/null; do
    exec 3< <(exec gdbus monitor --system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower 2>/dev/null)
    mon=$!
    while kill -0 "$sup" 2>/dev/null; do   # also notices a supervisor that died without stopping us
        if read -r -t 30 -u 3 line; then
            case "$line" in *"'LidIsClosed': <true>"*) on_close ;; esac
        elif [ $? -le 128 ]; then
            break   # the monitor ended (UPower restarted?): start a new one
        fi
    done
    exec 3<&-; kill "$mon" 2>/dev/null; sleep 2
done
