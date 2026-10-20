#!/usr/bin/env bash
# Load-check Quill next to the running desktop: starts a throwaway copy of the shell with its own runtime directory
# (so none of the real shell's sockets, lock flag or IPC are touched; Wayland is reached by the socket's full path),
# lets it run a few seconds and prints every QML error. Its windows show for those seconds (not while the screen is
# locked). Exit 0 when Quill loaded cleanly.
# Usage: tests/quill-check.sh [seconds] [classic]
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

secs="${1:-8}"
ui="${2:-quill}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"; sleep 1; reap_orphans' EXIT
chmod 700 "$tmp"

out="$(in_container '
    export QML_IMPORT_PATH="$1/qml" QML2_IMPORT_PATH="$1/qml"
    export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-wayland-1}" XDG_RUNTIME_DIR="$3" JF_UI="$4"
    export JF_QUILL_PROBE="$(cd "$2" && find quill -name "*.qml" | sort | xargs grep -L "pragma Singleton" | tr "\n" " ")"
    unset QT_QPA_PLATFORMTHEME
    cd "$3" && timeout "$5" quickshell -p "$2" 2>&1 | sed -u "s/\x1b\[[0-9;]*m//g"
' "$JF_INSTALL" "$JF_SHELL" "$tmp" "$ui" "$secs" 2>&1)"

errs="$(printf '%s\n' "$out" | grep -E "ERROR|qml:.*(Error|error)|TypeError|ReferenceError|is not a function|Cannot (read|assign)|Unable to assign|unavailable|is not a type|Binding loop|quill: failed|quill: probe" | grep -vE "Hyprland|HYPRLAND|wayland|Wayland|wl_display|pipewire|PipeWire|xdg-desktop|portal|ScreencopyView|Failed to create wl|libEGL|QDBus|org.freedesktop" | sort | uniq -c | sort -rn)"
printf '%s\n' "$out" | grep -E "quill: loaded|Configuration Loaded" | head -3
if [ -n "$errs" ]; then
    printf '%s\n' "$errs" | head -40 | cut -c1-700
    exit 1
fi
printf '%s\n' "$out" | grep -q "quill: loaded" || [ "$ui" != quill ] || { echo "Quill did not load"; printf '%s\n' "$out" | tail -20; exit 1; }
echo "clean"
