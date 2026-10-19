#!/usr/bin/env bash
# The yazi terminal file manager, set up the JellyFace way: no sudo, everything per user.
#   yazi.sh install    yazi + ya into ~/.local/bin, the Nerd Font symbols its icons need, config/yazi/ defaults
#                      (your own files are kept), and yazi + Kitty themes in the shell's colours (follow every change)
#   yazi.sh update     replace yazi with the latest release
#   yazi.sh theme      rewrite the yazi and Kitty themes from the current scheme now
#   yazi.sh status     what is installed, and which optional preview tools are missing
# Everything it creates or changes is recorded: `jellyface revert-system` takes it all back out.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
YAZI_CONFIG="$CONFIG_HOME/yazi"
KITTY_CONFIG="$CONFIG_HOME/kitty"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/jellyface-nerd-symbols"
BIN_DIR="$HOME/.local/bin"
TMP=""
trap '[ -z "$TMP" ] || rm -rf "$TMP"' EXIT   # downloads are cleaned up even when a step fails half-way

# Downloads one asset of a GitHub release and checks it against the SHA-256 digest GitHub publishes for it.
# fetch_release <owner/repo> <asset name> <out file>
fetch_release() {
    local api asset url digest
    need curl "Install it with: sudo apt install curl"
    need jq   "Install it with: sudo apt install jq"
    api="$(curl --proto '=https' --tlsv1.2 -sSfL "https://api.github.com/repos/$1/releases/latest")" \
        || die "could not reach GitHub for $1"
    asset="$(jq -c --arg n "$2" '.assets[] | select(.name == $n)' <<<"$api")"
    [ -n "$asset" ] || die "release asset $2 not found in $1"
    url="$(jq -r .browser_download_url <<<"$asset")"
    digest="$(jq -r '.digest // empty' <<<"$asset")"
    [[ "$digest" == sha256:* ]] || die "GitHub published no checksum for $2; not installing an unverified download"
    log "downloading $2 ($(jq -r .tag_name <<<"$api"))"
    curl --proto '=https' --tlsv1.2 -sSfL -o "$3" "$url" || die "download of $2 failed"
    echo "${digest#sha256:}  $3" | sha256sum -c --quiet - || die "$2 does not match its published checksum"
}

yazi_version() { yazi --version 2>/dev/null | awk '/Version/ && !v {v = $2} END {print v}'; }

install_yazi() {
    local triple
    case "$(uname -m)" in
        x86_64)        triple=x86_64-unknown-linux-gnu ;;
        aarch64|arm64) triple=aarch64-unknown-linux-gnu ;;
        *)             die "no yazi release for $(uname -m); build it from source: https://yazi-rs.github.io/docs/installation" ;;
    esac
    need unzip "Install it with: sudo apt install unzip"
    TMP="$(mktemp -d)"
    fetch_release sxyazi/yazi "yazi-$triple.zip" "$TMP/yazi.zip"
    unzip -q "$TMP/yazi.zip" -d "$TMP/out"
    mkdir -p "$BIN_DIR"
    sys_track "$BIN_DIR/yazi"; sys_track "$BIN_DIR/ya"
    install -m755 "$TMP/out/yazi-$triple/yazi" "$TMP/out/yazi-$triple/ya" "$BIN_DIR/"
    rm -rf "$TMP"; TMP=""
    log "installed yazi $(yazi_version) into $BIN_DIR"
}

# (no grep -q: under pipefail it closes the pipe early and fc-list's SIGPIPE turns "found" into "missing")
have_font() { fc-list : family | grep -i "Symbols Nerd Font" >/dev/null; }

install_font() {   # yazi's file icons are Nerd Font glyphs; Kitty and COSMIC Terminal pick them up from fontconfig
    if have_font; then log "Nerd Font symbols already installed"; return; fi
    need unzip "Install it with: sudo apt install unzip"
    TMP="$(mktemp -d)"
    fetch_release ryanoasis/nerd-fonts NerdFontsSymbolsOnly.zip "$TMP/font.zip"
    sys_track "$FONT_DIR"; mkdir -p "$FONT_DIR"
    unzip -qo "$TMP/font.zip" '*.ttf' -d "$FONT_DIR"
    rm -rf "$TMP"; TMP=""
    fc-cache -f "$FONT_DIR" >/dev/null
    log "installed Nerd Font symbols into $FONT_DIR"
}

# yazi previews HEIC, AVIF and JPEG XL with ImageMagick 7's `magick`. Ubuntu ships ImageMagick 6, which has no `magick`
# but whose `convert` takes the same arguments: a small stand-in hands over to a real `magick` once one is installed.
install_magick_shim() {
    local shim="$BIN_DIR/magick"
    if [ -e "$shim" ] && ! grep -q "JellyFace: stand-in" "$shim" 2>/dev/null; then return; fi   # yours: leave it
    if [ ! -e "$shim" ] && { command -v magick >/dev/null || ! command -v convert >/dev/null; }; then return; fi
    sys_track "$shim"; mkdir -p "$BIN_DIR"
    cat > "$shim" <<'SH'
#!/usr/bin/env bash
# JellyFace: stand-in for ImageMagick 7's `magick` (yazi uses it for HEIC/AVIF/JXL previews) on ImageMagick 6 systems.
# Uses a real `magick` further down PATH when there is one, otherwise IM6's `convert` (same arguments for these uses).
# Stand-ins (this one, or a copy elsewhere on PATH) are skipped: two of them must not hand over to each other forever.
for m in $(type -ap magick); do grep -q "JellyFace: stand-in" "$m" 2>/dev/null || exec "$m" "$@"; done
exec convert "$@"
SH
    chmod 755 "$shim"
    log "added a 'magick' stand-in for ImageMagick 6 (HEIC/AVIF/JXL previews)"
}

install_config() {   # only missing files: re-running never throws away your own settings (JF_RESET_CONFIG=1 restores ours)
    [ -e "$YAZI_CONFIG" ] || sys_track "$YAZI_CONFIG"
    mkdir -p "$YAZI_CONFIG"
    local f dest
    for f in "$JF_ROOT"/config/yazi/*; do
        dest="$YAZI_CONFIG/$(basename "$f")"
        if [ -e "$dest" ] && [ "${JF_RESET_CONFIG:-0}" != 1 ]; then log "keeping your $(basename "$f")"; continue; fi
        sys_track "$dest"
        if [ -e "$dest" ] && ! cmp -s "$f" "$dest"; then backup "$dest"; fi
        cp "$f" "$dest"
    done
}

install_themes() {   # yazi always; Kitty only when it is installed (its kitty.conf gets one include line, nothing else)
    sys_track "$YAZI_CONFIG/theme.toml"
    if ! command -v kitty >/dev/null && [ ! -d "$KITTY_CONFIG" ]; then
        log "Kitty not found: only yazi is themed (run 'jellyface files install' again after installing Kitty)"
        python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import theme; theme.update_yazi_theme(create=True)' \
            "$JF_ROOT/scripts"
        return
    fi
    [ -e "$KITTY_CONFIG" ] || sys_track "$KITTY_CONFIG"
    sys_track "$KITTY_CONFIG/kitty.conf"; sys_track "$KITTY_CONFIG/jellyface-theme.conf"
    python3 "$JF_ROOT/scripts/theme.py" terminals --setup
}

missing_tools() {   # optional: each one adds previews for more file types
    local spec missing=()
    for spec in ffmpeg:ffmpeg 7z:7zip magick:imagemagick pdftoppm:poppler-utils rg:ripgrep fdfind:fd-find fzf:fzf \
                zoxide:zoxide chafa:chafa; do
        command -v "${spec%%:*}" >/dev/null || missing+=("${spec##*:}")
    done
    echo "${missing[*]}"
}

status() {
    if command -v yazi >/dev/null; then log "yazi $(yazi_version)"; else log "yazi not installed"; fi
    if [ -d "$YAZI_CONFIG" ]; then log "config: $YAZI_CONFIG"; else log "config: $YAZI_CONFIG (missing)"; fi
    if have_font; then log "icon font: installed"; else log "icon font: missing"; fi
    local m; m="$(missing_tools)"
    if command -v convert >/dev/null && ! command -v magick >/dev/null; then
        m="${m/imagemagick/}"
        log "HEIC/AVIF/JXL previews need 'magick': run 'jellyface files install' (adds a stand-in for ImageMagick 6)"
    fi
    m="$(echo $m)"   # squeeze the gap a removed name leaves
    if [ -z "$m" ]; then log "all preview tools found"; else log "for more previews: sudo apt install $m"; fi
    if [ -z "${KITTY_WINDOW_ID:-}" ] && [ "${TERM:-}" != xterm-kitty ]; then
        log "tip: run yazi in Kitty for full-resolution image previews (other terminals may show coloured blocks)"
    fi
}

case "${1:-}" in
    install) command -v yazi >/dev/null || install_yazi
             install_font; install_magick_shim; install_config; install_themes
             status ;;
    update)  install_yazi ;;
    theme)   exec python3 "$JF_ROOT/scripts/theme.py" terminals ;;
    status)  status ;;
    *)       sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
