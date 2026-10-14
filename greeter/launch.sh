#!/bin/sh
# greetd's greeter command (runs as cosmic-greeter). Starts the JellyFace greeter; if anything is wrong it starts the
# stock COSMIC greeter instead, so you can ALWAYS log in. Every failure also signals the healer (heal-request).
. /usr/local/lib/jellyface-greeter/common.sh
JFG_WHO=launch
LOG=$JFG_RUN/launch.log

stock() {
    echo "$(date '+%F %T') -> stock greeter: $1" >> "$LOG"
    touch "$JFG_RUN/heal-request" 2>/dev/null     # signal: the .path unit starts the healer as root
    exec "$JFG_STOCK"
}

[ -e "$JFG_ETC/disabled" ] && exec "$JFG_STOCK"           # you switched it off: no signal, nothing to heal
[ -e "$JFG_ETC/broken" ] && stock "healer marked it broken"
[ -x "$JFG_ROOTFS/usr/bin/quickshell" ] || stock "rootfs missing"
[ -x "$JFG_LIB/enter" ] || stock "enter missing"
command -v sudo >/dev/null 2>&1 || stock "sudo missing"

fails=$(cat "$JFG_RUN/fails" 2>/dev/null); [ -n "$fails" ] || fails=0
[ "$fails" -ge 2 ] && stock "$fails consecutive failures"

rm -f "$JFG_RUN/alive"
[ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ] || {
    export XDG_RUNTIME_DIR=/run/cosmic-greeter/xdg
    mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
}
start=$(date +%s)
echo "$(date '+%F %T') start (fails=$fails)" >> "$LOG"

cosmic-comp sudo -n "$JFG_LIB/enter" >> "$LOG" 2>&1 &
cpid=$!

# watchdog: the greeter must show a heartbeat within 30s, else kill it (a black screen is the one failure that doesn't exit)
( i=0
  while [ "$i" -lt 30 ]; do
      [ -e "$JFG_RUN/alive" ] && exit 0
      kill -0 "$cpid" 2>/dev/null || exit 0
      sleep 1; i=$((i + 1))
  done
  echo "$(date '+%F %T') no heartbeat in 30s, killing" >> "$LOG"
  kill "$cpid" 2>/dev/null; sleep 2; kill -9 "$cpid" 2>/dev/null ) &
wpid=$!

wait "$cpid"; rc=$?
kill "$wpid" 2>/dev/null
ran=$(( $(date +%s) - start ))

if [ -e "$JFG_RUN/alive" ] && [ "$ran" -ge 3 ]; then
    echo 0 > "$JFG_RUN/fails"
    echo "$(date '+%F %T') ended ok (rc=$rc, ${ran}s)" >> "$LOG"
    exit 0
fi
echo $((fails + 1)) > "$JFG_RUN/fails"
stock "greeter failed (rc=$rc, ${ran}s, no heartbeat)"
