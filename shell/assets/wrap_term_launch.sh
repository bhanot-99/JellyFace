#!/usr/bin/env sh

cat ~/.local/state/jellyface/sequences.txt 2>/dev/null

exec "$@"
