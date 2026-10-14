#!/usr/bin/env bash
# JellyFace as a systemd *user* service: started by COSMIC's session at login, restarted if it fails, stopped at logout.
# Usage: service.sh on|off|status        (user-level only: nothing under /etc or /usr is touched)
set -uo pipefail
. "$(dirname "$0")/lib.sh"

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT="$UNIT_DIR/jellyface.service"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/jellyface.desktop"
need systemctl "systemd is required"

case "${1:-status}" in
    on)
        sys_track "$UNIT"
        mkdir -p "$UNIT_DIR"
        cat > "$UNIT" <<UNITEOF
[Unit]
Description=JellyFace desktop shell for COSMIC
Documentation=file://$JF_ROOT/README.md
After=graphical-session.target
PartOf=graphical-session.target
# give up after 5 failed starts within 5 minutes instead of looping forever
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
ExecStart=$JF_ROOT/bin/jellyface start --foreground
ExecStopPost=$JF_ROOT/bin/jellyface stop
Restart=on-failure
RestartSec=5
# the container's exec session can linger after a hard kill: don't wait long, ExecStopPost cleans up
TimeoutStopSec=10
SendSIGKILL=yes

[Install]
WantedBy=graphical-session.target
UNITEOF
        # the service replaces the plain autostart entry (never both) and any hand-started instance
        [ -e "$AUTOSTART" ] && "$JF_ROOT/bin/jellyface" autostart off >/dev/null 2>&1
        "$JF_ROOT/bin/jellyface" stop >/dev/null 2>&1
        systemctl --user daemon-reload
        systemctl --user enable --now jellyface.service
        log "service enabled: JellyFace now starts with your COSMIC session"
        ;;
    off)
        if systemctl --user cat jellyface.service >/dev/null 2>&1; then
            systemctl --user disable --now jellyface.service 2>&1 | tail -1
            log "service disabled (unit file kept; start by hand with: jellyface start)"
        else
            log "service is not installed"
        fi
        ;;
    status)
        systemctl --user --no-pager status jellyface.service 2>&1 | head -12
        ;;
    *) echo "usage: service.sh on|off|status" >&2; exit 2 ;;
esac
