#!/usr/bin/env bash
# `jellyface greeter ...`: JellyFace as the login screen. Root steps are never run for you: they are printed.
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
G="$JF_ROOT/greeter"; VAR=/var/lib/jellyface-greeter; ROOT_SH="$G/install-root.sh"

want_root() { printf '\nThis step needs root. Run:\n\n    sudo %s %s\n\n' "$ROOT_SH" "$1"; }

case "${1:-status}" in
    test)    exec "$JF_ROOT/tests/greeter-ui.sh" "${2:-}" ;;                      # headless, opens nothing
    window)  "$G/stage.sh" >/dev/null                                                # one visible test window (fake login)
             python3 "$JF_ROOT/tests/mock-greetd.py" "${TMPDIR:-/tmp}/jf-mock.sock" test >/dev/null 2>&1 & m=$!; sleep 0.5
             in_container "JF_GREETER_TEST=1 JF_GREETER_DATA='$JF_ROOT/.greeter-data' GREETD_SOCK='${TMPDIR:-/tmp}/jf-mock.sock' quickshell -p '$G'"; kill $m ;;
    stage)   "$G/stage.sh" "$([ -w "$VAR/data" ] && echo "$VAR/data")" ;;           # refresh wallpaper/colours/avatar
    export)  [ -f "$JF_ROOT/.greeter-root.tar" ] && [ "${2:-}" != --force ] && { log "already exported (use --force to redo)"; exit 0; }
             log "exporting the container's userland (3.9 GB)"; podman export "$JF_CONTAINER" -o "$JF_ROOT/.greeter-root.tar.partial" \
               && mv "$JF_ROOT/.greeter-root.tar.partial" "$JF_ROOT/.greeter-root.tar" ;;
    install|uninstall|enable|disable|rebuild) want_root "$1" ;;
    status)  [ -f "$VAR/STATUS" ] && cat "$VAR/STATUS" || echo "not installed"
             [ -f "$VAR/run/fails" ] && echo "consecutive failures: $(cat "$VAR/run/fails")"
             echo "--- last log lines"; tail -n 8 /var/log/jellyface-greeter.log 2>/dev/null; tail -n 4 "$VAR/run/launch.log" 2>/dev/null ;;
    heal)    want_root rebuild ;;
    *) echo "usage: jellyface greeter test|window|stage|export|install|uninstall|enable|disable|rebuild|status"; exit 2 ;;
esac
