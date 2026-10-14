#!/bin/sh
# Builds the COSMIC window helper (needs gcc, wayland-scanner, libwayland-client)
set -e
cd "$(dirname "$0")"
for x in ext-foreign-toplevel-list-v1 cosmic-toplevel-info-unstable-v1 cosmic-workspace-unstable-v1 ext-workspace-v1 cosmic-toplevel-management-unstable-v1; do
    wayland-scanner client-header $x.xml $x-client.h
    wayland-scanner private-code $x.xml $x-protocol.c
done
gcc -O2 -Wall -o wind.new wind.c ext-foreign-toplevel-list-v1-protocol.c cosmic-toplevel-info-unstable-v1-protocol.c \
    cosmic-workspace-unstable-v1-protocol.c ext-workspace-v1-protocol.c cosmic-toplevel-management-unstable-v1-protocol.c -lwayland-client
rm -f ./*-client.h ./*-protocol.c
mv -f wind.new wind   # replace atomically: a running copy must not block the build
