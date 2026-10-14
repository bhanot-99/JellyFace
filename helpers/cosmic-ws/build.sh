#!/bin/sh
# Builds the COSMIC workspace helper (needs gcc, wayland-scanner, libwayland-client)
set -e
cd "$(dirname "$0")"
wayland-scanner client-header ext-workspace-v1.xml ext-workspace-v1-client.h
wayland-scanner private-code ext-workspace-v1.xml ext-workspace-v1-protocol.c
gcc -O2 -Wall -o wsd wsd.c ext-workspace-v1-protocol.c -lwayland-client
rm -f ext-workspace-v1-client.h ext-workspace-v1-protocol.c
