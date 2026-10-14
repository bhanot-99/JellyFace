#!/usr/bin/env bash
# Opens Kooha (Flatpak), the screen recorder used with JellyFace. Runs on the HOST.
# Usage: record.sh open
# Kooha records through COSMIC's screen-cast portal and has no remote-control interface, so this only launches it
# (a second launch just raises the already-open window).
set -uo pipefail

APP=io.github.seadve.Kooha
DIR="${JF_RECORD_DIR:-$HOME/Videos/Recordings}"

note() { "$(dirname "$(readlink -f "$0")")/shims/notify-send" -a JellyFace "$@" || true; }

case "${1:-open}" in
    open)
        flatpak info "$APP" >/dev/null 2>&1 \
            || { note "Kooha is not installed" "Install it with: flatpak install --user flathub $APP"; exit 1; }
        mkdir -p "$DIR"
        # save recordings where the sidebar's recordings list looks (only set once, so a folder you choose yourself is kept)
        marker="${XDG_STATE_HOME:-$HOME/.local/state}/jellyface/kooha-configured"
        if [ ! -e "$marker" ]; then
            flatpak run --command=gsettings "$APP" set io.github.seadve.Kooha saving-location "b'$DIR'" 2>/dev/null \
                && { mkdir -p "$(dirname "$marker")"; touch "$marker"; }
        fi
        setsid nohup flatpak run "$APP" >/dev/null 2>&1 < /dev/null &
        ;;
    *) echo "usage: record.sh open" >&2; exit 2 ;;
esac
