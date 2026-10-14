#!/usr/bin/env bash
# Builds the COSMIC theme tool (project-local Rust; see scripts/rust-env.sh).
set -e
. "$(dirname "$0")/../../scripts/rust-env.sh"
cd "$(dirname "$0")"
cargo build --release
