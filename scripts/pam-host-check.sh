#!/usr/bin/env bash
# PAM helper for the lock screen (called by pam_exec with the typed password on stdin, NUL-terminated).
# The container account has no password, so the check is done by the HOST's own helper (unix_chkpwd), against
# your real login password. Anything unexpected -> exit 1 (reject): this must fail closed.
set -u
IFS= read -r -d '' pw || true            # the password, up to the NUL
user="${PAM_USER:-${USER:-}}"
fail() { sleep 1; exit 1; }              # 1s delay slows down guessing
[ -n "$pw" ] && [ -n "$user" ] || fail
printf '%s\0' "$pw" | distrobox-host-exec /usr/sbin/unix_chkpwd "$user" nonull >/dev/null 2>&1 || fail
exit 0
