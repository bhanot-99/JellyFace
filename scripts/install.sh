#!/usr/bin/env bash
# One-shot installer for Pop!_OS 24.04 (COSMIC). Safe to re-run.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

[ "${XDG_CURRENT_DESKTOP:-}" = "COSMIC" ] || warn "not running inside a COSMIC session (XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}')"
need distrobox "Install it with: sudo apt install distrobox podman"
need podman    "Install it with: sudo apt install podman"

# 1. container
if container_exists; then
    log "container '$JF_CONTAINER' already exists"
else
    log "creating Arch container '$JF_CONTAINER'"
    distrobox create --yes --name "$JF_CONTAINER" --image quay.io/toolbx/arch-toolbox:latest
fi

# 2. packages inside the container
log "installing packages in the container (asks for your sudo password inside the container)"
in_container '
set -e
sudo pacman -Syu --needed --noconfirm base-devel git cmake ninja \
    qt6-base qt6-declarative qt6-shadertools qt6-svg qt6-wayland qt6-imageformats \
    libpipewire aubio libqalculate networkmanager ddcutil brightnessctl lm_sensors \
    grim swappy wl-clipboard fish pipewire-pulse power-profiles-daemon \
    ttf-material-symbols-variable ttf-cascadia-code-nerd mesa vulkan-intel vulkan-radeon
if ! command -v yay >/dev/null; then
    tmp=$(mktemp -d); git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
fi
yay -S --needed --noconfirm quickshell-git qt6-m3shapes-git libcava
'

# 3. screen recorder (Kooha, a Flatpak on the host; it records through COSMIC's screen-cast portal)
if command -v flatpak >/dev/null; then
    flatpak info io.github.seadve.Kooha >/dev/null 2>&1 \
        || flatpak install --user -y flathub io.github.seadve.Kooha \
        || warn "could not install Kooha; the sidebar's recorder button will not work (flatpak install --user flathub io.github.seadve.Kooha)"
else
    warn "flatpak not found; install it (sudo apt install flatpak) and Kooha for screen recording"
fi

# 4. build helper + plugin
"$JF_ROOT/scripts/build.sh"

# 5. default config (existing files are backed up first, never deleted)
mkdir -p "$JF_CONFIG_DIR" "$JF_STATE_DIR"
for f in shell.json shell-tokens.json; do
    if [ -e "$JF_CONFIG_DIR/$f" ] && ! cmp -s "$JF_ROOT/config/$f" "$JF_CONFIG_DIR/$f"; then backup "$JF_CONFIG_DIR/$f"; fi
    cp "$JF_ROOT/config/$f" "$JF_CONFIG_DIR/$f"
done
if [ -e "$JF_STATE_DIR/scheme.json" ] && ! cmp -s "$JF_ROOT/config/scheme.json" "$JF_STATE_DIR/scheme.json"; then backup "$JF_STATE_DIR/scheme.json"; fi
cp "$JF_ROOT/config/scheme.json" "$JF_STATE_DIR/scheme.json"

"$JF_ROOT/scripts/fix-icons.sh"
log "done. Next:  jellyface start --timeout 120   (safe first run)   |   jellyface cosmic-tweaks   (optional)"
