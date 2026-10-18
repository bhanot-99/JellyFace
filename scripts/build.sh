#!/usr/bin/env bash
# Builds (1) the COSMIC workspace helper on the host and (2) the shell's native QML plugin in the container.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

log "building COSMIC helpers: workspaces + windows (host)"
need gcc "Install it with: sudo apt install build-essential libwayland-dev libwayland-bin"
need wayland-scanner "Install it with: sudo apt install libwayland-bin"
"$JF_ROOT/helpers/cosmic-ws/build.sh"
"$JF_ROOT/helpers/cosmic-windows/build.sh"

if [ "${JF_SKIP_RUST:-0}" != 1 ]; then
    log "building the COSMIC theme tool (installs a project-local Rust toolchain on first run)"
    "$JF_ROOT/tools/cosmic-theme/build.sh" || warn "theme tool not built; COSMIC's own theme will not follow the palette"
    log "building the native COSMIC applet"
    "$JF_ROOT/native/build.sh" || warn "applet not built (the shell itself is unaffected)"
fi

log "building shell plugin (container: $JF_CONTAINER) -- this takes a few minutes"
container_exists || die "container '$JF_CONTAINER' does not exist. Run: jellyface install"
rev="$(git -C "$JF_SHELL" rev-parse HEAD 2>/dev/null || echo unknown)"
# the version the shell reports comes from the newest released section of the changelog, not a number kept here too
version="$(sed -n 's/^## \([0-9][0-9.]*\).*/\1/p' "$JF_ROOT/CHANGELOG.md" | head -1)"; version="${version:-0.0.0}"
in_container '
set -e
cd "$1"
cmake -S . -B "$2" -G Ninja -DCMAKE_BUILD_TYPE=Release -DVERSION="$5" -DGIT_REVISION="$4" \
    -DCMAKE_INSTALL_PREFIX="$3" -DINSTALL_LIBDIR="$3/lib" -DINSTALL_QMLDIR="$3/qml" -DINSTALL_QSCONFDIR="$3/qs-config"
cmake --build "$2"
cmake --install "$2"
' "$JF_SHELL" "$JF_BUILD" "$JF_INSTALL" "$rev" "$version"
log "build complete"
