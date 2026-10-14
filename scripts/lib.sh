# Shared helpers for JellyFace scripts. Source this file, don't run it.
JF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[ -f "$JF_ROOT/.env.local" ] && . "$JF_ROOT/.env.local"

JF_CONTAINER="${JF_CONTAINER:-jellyface}"   # distrobox container that runs the shell
JF_SHELL="$JF_ROOT/shell"                   # patched Caelestia shell (QML)
JF_BUILD="$JF_ROOT/.build"                  # cmake build tree (regenerable)
JF_INSTALL="$JF_ROOT/.install"              # built QML plugin + version binary (regenerable)
JF_BACKUPS="${JF_BACKUPS:-$JF_ROOT/backups}"
# Anchored process patterns: they match only the processes JellyFace starts, never an unrelated command line
# that merely contains the same text (e.g. a grep, an editor, or a terminal running this very command).
JF_QS_RE="^quickshell -p ${JF_SHELL}\$"
JF_WSD_RE="^${JF_SHELL}/\\.\\./helpers/cosmic-ws/wsd\$"
JF_SUP_RE="^((/usr)?/bin/)?bash ${JF_ROOT}/scripts/run\\.sh"
JF_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia"
JF_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

log()  { printf '\033[1;35m[jellyface]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[jellyface] warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[jellyface] error:\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found. $2"; }

container_exists() { distrobox list 2>/dev/null | awk -F'|' 'NR>1{gsub(/ /,"",$2);print $2}' | grep -qx "$JF_CONTAINER"; }

# Run a bash snippet inside the container: in_container '<script>' [args...]
in_container() { local s="$1"; shift; distrobox enter "$JF_CONTAINER" -- bash -c "$s" _ "$@"; }

# Back up a file or directory into backups/ (never overwrites, never deletes anything)
backup() {
    local src="$1"
    [ -e "$src" ] || return 0
    mkdir -p "$JF_BACKUPS"
    local dest
    dest="$JF_BACKUPS/$(basename "$src").$(date +%Y%m%d-%H%M%S)"
    cp -a "$src" "$dest"
    log "backed up $src -> $dest"
}
