#!/bin/sh
# Builds the COSMIC theme tool. Rust is installed inside the project (.rust/), never system-wide, if it is missing.
# Skip all of this with JF_SKIP_RUST=1 (JellyFace then themes only its own surfaces, not COSMIC's apps).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export CARGO_HOME="$ROOT/.rust/cargo" RUSTUP_HOME="$ROOT/.rust/rustup"
export PATH="$CARGO_HOME/bin:$PATH"
if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
    echo "[jellyface] installing the Rust toolchain into $ROOT/.rust (about 600 MB, project-local)"
    command -v curl >/dev/null || { echo "curl is required"; exit 1; }
    curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable
fi
cd "$ROOT/tools/cosmic-theme"
cargo build --release
