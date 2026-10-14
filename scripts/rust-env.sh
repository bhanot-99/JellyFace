# Source this file: sets up the project-local Rust toolchain (installs it into .rust/ if missing) and the
# build-time stand-ins for system libraries that exist at runtime but have no -dev package installed.
# Nothing is installed system-wide, and no sudo is needed.
JF_RUST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export CARGO_HOME="$JF_RUST_ROOT/.rust/cargo" RUSTUP_HOME="$JF_RUST_ROOT/.rust/rustup"
export PATH="$CARGO_HOME/bin:$PATH"
if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
    echo "[jellyface] installing the Rust toolchain into $JF_RUST_ROOT/.rust (about 600 MB, project-local)"
    command -v curl >/dev/null || { echo "curl is required"; return 1 2>/dev/null || exit 1; }
    curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable || return 1
fi
# stand-in "-dev" metadata: the Rust build only needs the library to link against, not its headers
JF_FAKELIBS="$JF_RUST_ROOT/.rust/fakelibs"
mkdir -p "$JF_FAKELIBS/lib" "$JF_FAKELIBS/pkgconfig"
for spec in "xkbcommon:libxkbcommon.so.0"; do
    name="${spec%%:*}"; so="${spec##*:}"
    real="$(ls /usr/lib/x86_64-linux-gnu/$so /usr/lib64/$so /usr/lib/$so 2>/dev/null | head -1)"
    [ -n "$real" ] || continue
    ln -sf "$real" "$JF_FAKELIBS/lib/lib$name.so"
    # only if the system has no real .pc file
    pkg-config --exists "$name" 2>/dev/null && continue
    cat > "$JF_FAKELIBS/pkgconfig/$name.pc" <<PCEOF
prefix=$JF_FAKELIBS
libdir=\${prefix}/lib
Name: $name
Description: project-local stand-in for the system library (no headers needed for Rust builds)
Version: 1.0
Libs: -L\${libdir} -l$name
Cflags:
PCEOF
done
export PKG_CONFIG_PATH="$JF_FAKELIBS/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
