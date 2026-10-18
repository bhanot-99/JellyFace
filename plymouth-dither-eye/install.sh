#!/usr/bin/env bash
# Installs the theme and rebuilds the initramfs. Needs sudo. Pop!_OS/Ubuntu only.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest=/usr/share/plymouth/themes/dither-eye
sudo rm -rf "$dest"
sudo mkdir -p "$dest"
sudo cp -r "$here/dither-eye.plymouth" "$here/dither-eye.script" "$here/frames" "$dest/"
sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$dest/dither-eye.plymouth" 150
sudo update-alternatives --set default.plymouth "$dest/dither-eye.plymouth"
sudo update-initramfs -u
