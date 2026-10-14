#!/usr/bin/env bash
# Builds the native COSMIC applet(s) (project-local Rust; see scripts/rust-env.sh).
set -e
. "$(dirname "$0")/../scripts/rust-env.sh"
cd "$(dirname "$0")/jellyface-applet"
cargo build --release
