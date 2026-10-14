#!/usr/bin/env bash
# Makes JellyFace part of the COSMIC session in one go. Shows the plan first and asks before changing anything.
#   integrate.sh [--yes]
# Every step is user-level, snapshotted first, and undone by `jellyface revert-system`.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

cat <<PLAN
JellyFace will integrate with your COSMIC session:
  1. snapshot your COSMIC settings into backups/ (kept forever)
  2. start JellyFace with the session as a systemd user service (restarts on failure)
  3. auto-hide COSMIC's top panel and set Super+L to JellyFace's lock screen
  4. register the JellyFace menu as a native panel applet and add it to your panel
  5. make COSMIC's own apps (Files, Terminal, Settings...) follow the palette
Nothing under /usr or /etc is touched, no sudo is used, and 'jellyface revert-system' puts it all back.
PLAN
if [ "${1:-}" != "--yes" ]; then
    printf 'Continue? [y/N] '; read -r a; case "$a" in y|Y|yes) ;; *) echo "cancelled; nothing changed"; exit 0 ;; esac
fi

ts="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$JF_BACKUPS"; cp -a "${XDG_CONFIG_HOME:-$HOME/.config}/cosmic" "$JF_BACKUPS/cosmic-config-before-integration-$ts"
log "1/5 snapshot saved: backups/cosmic-config-before-integration-$ts"
log "2/5 service";  "$JF_ROOT/scripts/service.sh" on
log "3/5 panel + lock shortcut"; "$JF_ROOT/scripts/cosmic-tweaks.sh"
log "4/5 applet";   "$JF_ROOT/scripts/applet.sh" install && "$JF_ROOT/scripts/applet.sh" panel-add
log "5/5 COSMIC theme"; python3 -I "$JF_ROOT/scripts/theme.py" system on
log "done. Undo everything any time with: jellyface revert-system"
