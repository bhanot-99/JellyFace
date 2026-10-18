#!/usr/bin/env bash
# PAM helper for the lock screen (called by pam_exec with the typed password on stdin, NUL-terminated).
# The container account has no password, so the check is done by the HOST's own helper (unix_chkpwd), against
# your real login password. Anything unexpected -> exit 1 (reject): this must fail closed.
set -u
IFS= read -r -d '' pw || true            # the password, up to the NUL
user="${PAM_USER:-${USER:-}}"

# Consecutive wrong passwords slow guessing down: 1s each, then 2s, 4s, 8s ... up to 30s. The counter lives in the
# per-user runtime dir and starts over after 10 quiet minutes or a correct password. A correct password is never delayed.
state="${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/jellyface-lock-fails}"
fail() {
    local n=0 d=1
    if [ -n "$state" ] && [ -f "$state" ] && [ $(( $(date +%s) - $(stat -c %Y "$state" 2>/dev/null || echo 0) )) -lt 600 ]; then
        n=$(cat "$state" 2>/dev/null)
    fi
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    n=$(( n + 1 )); [ "$n" -gt 12 ] && n=12
    [ -n "$state" ] && ( umask 077; echo "$n" > "$state" ) 2>/dev/null
    [ "$n" -gt 3 ] && d=$(( 1 << (n - 3) ))
    [ "$d" -gt 30 ] && d=30
    sleep "$d"; exit 1
}
[ -n "$pw" ] && [ -n "$user" ] || fail
printf '%s\0' "$pw" | distrobox-host-exec /usr/sbin/unix_chkpwd "$user" nonull >/dev/null 2>&1 || fail
[ -n "$state" ] && rm -f "$state"
exit 0
