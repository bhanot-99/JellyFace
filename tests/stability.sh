#!/usr/bin/env bash
# Stability tests: restarts, crashes, double starts, cold container, bad config, drawer stress, memory.
# Usage: tests/stability.sh [--quick]     Needs a running COSMIC session. Stops any running JellyFace first.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
JF="$JF_ROOT/bin/jellyface"
QUICK=0; [ "${1:-}" = "--quick" ] && QUICK=1
pass=0; failn=0
ok()   { pass=$((pass+1)); printf '  \033[32mPASS\033[0m %s\n' "$*"; }
bad()  { failn=$((failn+1)); printf '  \033[31mFAIL\033[0m %s\n' "$*"; }
check() { if eval "$2"; then ok "$1"; else bad "$1  [$2]"; fi; }
n_shell() { pgrep -f "$JF_QS_RE" | wc -l; }
n_wsd()   { pgrep -f "$JF_WSD_RE" | wc -l; }
n_wind()  { pgrep -f "$JF_WIND_RE" | wc -l; }
n_sup()   { pgrep -f "$JF_SUP_RE" | wc -l; }
wait_up() { for _ in $(seq 1 "${1:-40}"); do [ "$(n_shell)" -ge 1 ] && [ "$(n_wsd)" -ge 1 ] && [ "$(n_wind)" -ge 1 ] && return 0; sleep 1; done; return 1; }
wait_cfg() { sleep "${1:-8}"; }
runlog_start() { LOGMARK=$(wc -l < "$JF_ROOT/logs/jellyface.log" 2>/dev/null || echo 0); }
runlog() { tail -n +$((LOGMARK+1)) "$JF_ROOT/logs/jellyface.log" 2>/dev/null; }
# The systemd service would fight these tests (it owns the supervisor): pause it, and bring it back at the end.
SERVICE_WAS_ACTIVE=0
if systemctl --user is-active --quiet jellyface.service 2>/dev/null; then
    SERVICE_WAS_ACTIVE=1; systemctl --user stop jellyface.service
fi
restore() {
    "$JF" stop >/dev/null 2>&1
    [ "$SERVICE_WAS_ACTIVE" = 1 ] && systemctl --user start jellyface.service
}
trap restore EXIT

"$JF" stop >/dev/null 2>&1; sleep 2
mkdir -p "$JF_ROOT/logs"; runlog_start

echo "1. clean start"
"$JF" start >/dev/null; wait_up 60
check "one supervisor, one shell, one of each helper" '[ "$(n_sup)" -eq 1 ] && [ "$(n_shell)" -eq 1 ] && [ "$(n_wsd)" -eq 1 ] && [ "$(n_wind)" -eq 1 ]'

echo "2. double start is a no-op"
"$JF" start >/dev/null; "$JF" start >/dev/null; sleep 3
check "still exactly one of each" '[ "$(n_sup)" -eq 1 ] && [ "$(n_shell)" -eq 1 ] && [ "$(n_wsd)" -eq 1 ]'

echo "3. crash recovery (kill -9 the shell)"
pkill -9 -f "$JF_QS_RE"; sleep 1
check "helper does not outlive the crashed shell" '[ "$(n_wsd)" -le 1 ]'
wait_up 40
check "supervisor restarted the shell and helper" '[ "$(n_shell)" -eq 1 ] && [ "$(n_wsd)" -eq 1 ]'

echo "4. helper killed -> shell respawns it"
pkill -9 -f "$JF_WSD_RE"; sleep 6
check "helper is back" '[ "$(n_wsd)" -eq 1 ]'
check "shell survived" '[ "$(n_shell)" -eq 1 ]'

echo "5. repeated stop/start cycles"
cycles=$([ $QUICK = 1 ] && echo 3 || echo 8)
leak=0; why=""
for i in $(seq 1 "$cycles"); do
    "$JF" stop >/dev/null; sleep 1
    if [ "$(n_shell)" -ne 0 ] || [ "$(n_wsd)" -ne 0 ] || [ "$(n_sup)" -ne 0 ]; then
        leak=$((leak+1)); why="$why cycle$i:leftover(shell=$(n_shell),wsd=$(n_wsd),sup=$(n_sup))"
    fi
    "$JF" start >/dev/null
    wait_up 60 || { leak=$((leak+1)); why="$why cycle$i:not-up(shell=$(n_shell),wsd=$(n_wsd),sup=$(n_sup))"; }
done
[ -n "$why" ] && echo "  detail:$why"
check "$cycles cycles: no leftovers after stop, healthy after start" '[ "$leak" -eq 0 ]'
check "exactly one of each at the end" '[ "$(n_sup)" -eq 1 ] && [ "$(n_shell)" -eq 1 ] && [ "$(n_wsd)" -eq 1 ]'

echo "6. invalid config does not prevent startup"
"$JF" stop >/dev/null; sleep 1
export JF_BACKUPS; JF_BACKUPS="$(mktemp -d)"   # keep test leftovers out of the real backups/
cp "$JF_CONFIG_DIR/shell.json" /tmp/jf-shell.json.keep
echo '{ this is not json' > "$JF_CONFIG_DIR/shell.json"
"$JF" start >/dev/null; wait_up 60
check "shell is up" '[ "$(n_shell)" -eq 1 ]'
check "config was repaired" 'python3 -I -c "import json;json.load(open(\"$JF_CONFIG_DIR/shell.json\"))"'
check "broken file was backed up, not lost" 'ls "$JF_BACKUPS"/shell.json.* >/dev/null 2>&1'
unset JF_BACKUPS; . "$(dirname "$0")/../scripts/lib.sh"
cp /tmp/jf-shell.json.keep "$JF_CONFIG_DIR/shell.json"; rm -f /tmp/jf-shell.json.keep

echo "7. cold container (as after a reboot)"
"$JF" stop >/dev/null; sleep 1
distrobox stop --yes "$JF_CONTAINER" >/dev/null 2>&1; sleep 3
"$JF" start >/dev/null; wait_up 90
check "shell comes up from a stopped container" '[ "$(n_shell)" -eq 1 ] && [ "$(n_wsd)" -eq 1 ]'

echo "8. drawer stress (IPC toggles)"
sleep 5; runlog_start
rounds=$([ $QUICK = 1 ] && echo 5 || echo 25)
for i in $(seq 1 "$rounds"); do
    for d in launcher dashboard sidebar session utilities; do "$JF" ipc drawers toggle "$d" >/dev/null 2>&1; sleep 0.15; done
done
sleep 1
for d in launcher dashboard sidebar session utilities; do # make sure everything is closed again
    "$JF" ipc drawers toggle "$d" >/dev/null 2>&1; sleep 0.1
done
sleep 3
check "shell survived $((rounds*5)) toggles" '[ "$(n_shell)" -eq 1 ]'
errs=$(runlog | grep -E "TypeError|ReferenceError|Unable to assign|is not a function|Cannot read property|Cannot assign|Binding loop|SIGSEGV|crash" | sed 's/\x1b\[[0-9;]*m//g' | sort | uniq -c | sort -rn)
check "no QML runtime errors in the log" '[ -z "$errs" ]'
[ -n "$errs" ] && echo "$errs" | head -8 | cut -c1-200

echo "9. memory"
pid=$(pgrep -f "$JF_QS_RE" | head -1); rss1=$(awk '/VmRSS/{print $2}' /proc/$pid/status 2>/dev/null || echo 0)
if [ $QUICK = 0 ]; then
    for i in $(seq 1 30); do for d in launcher dashboard sidebar session utilities; do "$JF" ipc drawers toggle "$d" >/dev/null 2>&1; done; sleep 0.2; done
    for d in launcher dashboard sidebar session utilities; do "$JF" ipc drawers toggle "$d" >/dev/null 2>&1; done
    sleep 5
fi
rss2=$(awk '/VmRSS/{print $2}' /proc/$pid/status 2>/dev/null || echo 0)
echo "  RSS ${rss1} kB -> ${rss2} kB"
check "memory grew by less than 25% under stress" '[ "$rss2" -lt $((rss1 * 125 / 100)) ]'

echo
echo "result: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
