#!/bin/bash
# Root helper, the ONLY thing sudoers lets cosmic-greeter run (no arguments). Enters the Arch userland copy and runs the
# greeter there as cosmic-greeter. `enter --smoke` (root only) = headless load test, used by the healer.
set -eu
. /usr/local/lib/jellyface-greeter/common.sh
U=cosmic-greeter
uid=$(id -u "$U"); gid=$(id -g "$U")
mode=run
[ "${1:-}" = "--smoke" ] && [ "$(id -u)" = 0 ] && [ "${SUDO_USER:-root}" != "$U" ] && mode=smoke

if [ "$mode" = run ]; then
    # the environment comes from the (less trusted) greeter user: validate before using it in paths
    case "${WAYLAND_DISPLAY:-}" in ''|*[!A-Za-z0-9._-]*) exit 64 ;; esac
    XRD="${XDG_RUNTIME_DIR:-}"
    [ -d "$XRD" ] && [ "$(stat -c %u "$XRD")" = "$uid" ] || exit 65
    case "${GREETD_SOCK:-}" in /run/*) ;; *) exit 66 ;; esac
    case "$XRD${GREETD_SOCK}" in *..*) exit 67 ;; esac
else
    export WAYLAND_DISPLAY=none XDG_RUNTIME_DIR=/tmp GREETD_SOCK=/nonexistent
fi

# the Arch copy has no timezone of its own (empty /etc/localtime = UTC): hand it the host's, so the clock is right
TZ=$(timedatectl show -p Timezone --value 2>/dev/null || true)
[ -n "$TZ" ] || TZ=$(readlink -f /etc/localtime | sed -n 's|.*/zoneinfo/||p')
case "$TZ" in ''|*[!A-Za-z0-9._+/-]*|*..*) TZ=UTC ;; esac

export JFG_ROOTFS JFG_PRISTINE_QML=$JFG_OPT/qml uid gid mode TZ
exec unshare --mount --propagation private bash -c '
    set -eu
    R=$JFG_ROOTFS
    # the Arch userland keeps its setuid programs: no suid/sgid effect inside it (here, and below via no_new_privs)
    mount --bind "$R" "$R"; mount -o remount,bind,nosuid "$R"
    mount --rbind /dev  "$R/dev"
    mount -t proc proc  "$R/proc"
    mount --rbind /sys  "$R/sys"
    mount --rbind /run  "$R/run"
    mkdir -p "$R/jf-qml" "$R/jf-data" "$R/tmp"
    mount --bind "$JFG_PRISTINE_QML" "$R/jf-qml"; mount -o remount,bind,ro "$R/jf-qml"
    mount --bind /var/lib/jellyface-greeter "$R/jf-data"
    env=(env -i PATH=/usr/bin HOME=/tmp LANG=C.UTF-8 TZ="$TZ" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
         GREETD_SOCK="$GREETD_SOCK" QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software QS_NO_RELOAD_POPUP=1
         JF_GREETER_DATA=/jf-data/data JF_GREETER_RUN=/jf-data/run)
    if [ "$mode" = smoke ]; then
        env=("${env[@]}" QT_QPA_PLATFORM=offscreen JF_GREETER_TEST=1)
        exec setpriv --no-new-privs chroot --userspec="$uid:$gid" "$R" "${env[@]}" timeout 8 quickshell -p /jf-qml
    fi
    exec setpriv --no-new-privs chroot --userspec="$uid:$gid" "$R" "${env[@]}" quickshell -p /jf-qml
'
