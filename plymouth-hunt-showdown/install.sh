#!/usr/bin/env bash
# Installs the theme and rebuilds the initramfs. Needs sudo. Pop!_OS/Ubuntu only.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest=/usr/share/plymouth/themes/hunt-showdown
sudo rm -rf "$dest"
sudo mkdir -p "$dest"
sudo cp -r "$here/hunt-showdown.plymouth" "$here/hunt-showdown.script" "$here/frames" "$dest/"
sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$dest/hunt-showdown.plymouth" 160
sudo update-alternatives --set default.plymouth "$dest/hunt-showdown.plymouth"
sudo update-initramfs -u
