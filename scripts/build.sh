#!/usr/bin/env bash
# Builds (1) the COSMIC workspace helper on the host and (2) the shell's native QML plugin in the container.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

log "building workspace helper (host)"
need gcc "Install it with: sudo apt install build-essential libwayland-dev libwayland-bin"
need wayland-scanner "Install it with: sudo apt install libwayland-bin"
"$JF_ROOT/helpers/cosmic-ws/build.sh"

log "building shell plugin (container: $JF_CONTAINER) -- this takes a few minutes"
container_exists || die "container '$JF_CONTAINER' does not exist. Run: jellyface install"
rev="$(git -C "$JF_SHELL" rev-parse HEAD 2>/dev/null || echo unknown)"
in_container '
set -e
cd "$1"
cmake -S . -B "$2" -G Ninja -DCMAKE_BUILD_TYPE=Release -DVERSION=1.0.0 -DGIT_REVISION="$4" \
    -DCMAKE_INSTALL_PREFIX="$3" -DINSTALL_LIBDIR="$3/lib" -DINSTALL_QMLDIR="$3/qml" -DINSTALL_QSCONFDIR="$3/qs-config"
cmake --build "$2"
cmake --install "$2"
' "$JF_SHELL" "$JF_BUILD" "$JF_INSTALL" "$rev"
log "build complete"
