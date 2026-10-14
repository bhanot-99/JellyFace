#!/bin/sh
# Builds the touchpad gesture helper (needs gcc and the kernel headers only)
set -e
cd "$(dirname "$0")"
gcc -O2 -Wall -o gestured.new gestured.c -lm
mv -f gestured.new gestured   # replace atomically: a running copy must not block the build
