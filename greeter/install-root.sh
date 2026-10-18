#!/bin/bash
# Root part of the JellyFace greeter. Run through `jellyface greeter ...` (it prints the exact sudo command).
#   install      put everything in place, prove the greeter loads, THEN switch greetd over (never before the proof)
#   uninstall    point greetd back at the stock COSMIC greeter (nothing is deleted)
#   enable|disable   switch the JellyFace greeter on/off without uninstalling
#   rebuild      replace the Arch userland copy with .greeter-root.tar and re-run the healer
set -eu
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; proj="$(dirname "$here")"
owner="${SUDO_USER:-}"; [ -n "$owner" ] && [ "$owner" != root ] || { echo "run via sudo from your own account"; exit 1; }
. "$here/common.sh"
JFG_WHO=install
say() { printf '\033[1;35m[greeter]\033[0m %s\n' "$*"; }

extract_rootfs() {
    [ -f "$proj/.greeter-root.tar" ] || { echo "missing $proj/.greeter-root.tar (run: jellyface greeter export)"; exit 1; }
    say "unpacking the Arch userland (3.9 GB, a minute or two)"
    rm -rf "$JFG_ROOTFS.new"; mkdir -p "$JFG_ROOTFS.new"
    tar -xpf "$proj/.greeter-root.tar" --numeric-owner -C "$JFG_ROOTFS.new" 2>"$JFG_ROOTFS.new.err" \
        || { say "tar reported problems (last lines below); continuing only if the userland still starts"; tail -5 "$JFG_ROOTFS.new.err"; }
    rm -f "$JFG_ROOTFS.new.err"
    [ -x "$JFG_ROOTFS.new/usr/bin/quickshell" ] || { echo "unpacked tree has no quickshell"; exit 1; }
    # keep ONE previous userland as a way back (each is ~4 GB), drop the older ones
    for old in "$JFG_ROOTFS".old.*; do [ -e "$old" ] && rm -rf -- "$old"; done
    [ -d "$JFG_ROOTFS" ] && mv "$JFG_ROOTFS" "$JFG_ROOTFS.old.$(date +%s)"
    mv "$JFG_ROOTFS.new" "$JFG_ROOTFS"
}

put_files() {
    install -d -m 755 "$JFG_LIB" "$JFG_OPT" "$JFG_PRISTINE" "$JFG_ETC" "$JFG_VAR"
    install -d -m 755 -o cosmic-greeter -g cosmic-greeter "$JFG_RUN"
    install -d -m 755 -o "$owner" -g "$owner" "$JFG_VAR/data"
    install -m 755 "$here/launch.sh" "$JFG_LIB/launch";  install -m 755 "$here/launch.sh" "$JFG_PRISTINE/launch"
    install -m 755 "$here/enter.sh"  "$JFG_LIB/enter";   install -m 755 "$here/enter.sh"  "$JFG_PRISTINE/enter"
    install -m 755 "$here/heal.sh"   "$JFG_LIB/heal";    install -m 755 "$here/heal.sh"   "$JFG_PRISTINE/heal"
    install -m 644 "$here/common.sh" "$JFG_LIB/common.sh"; install -m 644 "$here/common.sh" "$JFG_PRISTINE/common.sh"
    rm -rf "$JFG_OPT/qml" "$JFG_PRISTINE/qml"; mkdir -p "$JFG_OPT/qml"
    cp "$here/shell.qml" "$here/Panels.qml" "$JFG_OPT/qml/"; cp -a "$JFG_OPT/qml" "$JFG_PRISTINE/qml"
    echo "$owner" > "$JFG_PRISTINE/owner"
    # sudoers: validate BEFORE it goes live (a bad file would break sudo for everyone)
    cp "$here/sudoers" "$JFG_PRISTINE/sudoers"
    visudo -cf "$JFG_PRISTINE/sudoers" >/dev/null || { echo "sudoers file invalid, aborting"; exit 1; }
    install -m 440 -o root -g root "$JFG_PRISTINE/sudoers" /etc/sudoers.d/jellyface-greeter
    visudo -c >/dev/null || { mv /etc/sudoers.d/jellyface-greeter /etc/sudoers.d/jellyface-greeter.bad; echo "sudo check failed, undone"; exit 1; }
    install -m 644 "$here/jellyface-greeter-heal.service" "$here/jellyface-greeter-heal.path" /etc/systemd/system/
    systemctl daemon-reload
}

case "${1:-}" in
install)
    [ -d "$JFG_ROOTFS" ] || extract_rootfs
    put_files
    sudo -u "$owner" bash "$here/stage.sh" "$JFG_VAR/data" >/dev/null
    say "load test (headless, ~8s) before touching the login screen"
    set +e; out=$("$JFG_LIB/enter" --smoke 2>&1); rc=$?; set -e
    if [ "$rc" -ne 124 ] || printf '%s' "$out" | grep -qiE 'failed to load configuration|error'; then
        echo "$out" | tail -15; echo "load test FAILED (rc=$rc): login screen NOT changed."; exit 1
    fi
    if ! grep -q "^command = \"$JFG_LIB/launch\"" "$JFG_GREETD_CONF"; then
        [ -f "$JFG_GREETD_CONF.jellyface-orig" ] || cp -a "$JFG_GREETD_CONF" "$JFG_GREETD_CONF.jellyface-orig"
        mkdir -p "$proj/backups"; cp -a "$JFG_GREETD_CONF" "$proj/backups/cosmic-greeter.toml.$(date +%Y%m%d-%H%M%S)"
        sed -i "s|^command = \"cosmic-greeter-start\"|command = \"$JFG_LIB/launch\"|" "$JFG_GREETD_CONF"
        grep -q "^command = \"$JFG_LIB/launch\"" "$JFG_GREETD_CONF" || { echo "could not edit greetd config"; exit 1; }
    fi
    cp -a "$JFG_GREETD_CONF" "$JFG_PRISTINE/cosmic-greeter.toml"
    rm -f "$JFG_ETC/disabled" "$JFG_ETC/broken"; jfg_reset_fails
    systemctl enable --now jellyface-greeter-heal.path >/dev/null 2>&1
    systemctl enable jellyface-greeter-heal.service >/dev/null 2>&1
    printf 'OK: JellyFace greeter active\n%s\n' "$(date '+%F %T')" > "$JFG_STATUS"; chmod 644 "$JFG_STATUS"
    say "done. The new login screen appears at the next boot/logout. If it ever fails, the stock COSMIC login starts instead and the healer runs by itself."
    ;;
uninstall)
    [ -f "$JFG_GREETD_CONF.jellyface-orig" ] && cp -a "$JFG_GREETD_CONF.jellyface-orig" "$JFG_GREETD_CONF"
    touch "$JFG_ETC/disabled"
    systemctl disable --now jellyface-greeter-heal.path jellyface-greeter-heal.service >/dev/null 2>&1 || true
    say "stock COSMIC greeter restored (files under /opt/jellyface-greeter and the backup were kept)"
    ;;
disable) install -d "$JFG_ETC"; touch "$JFG_ETC/disabled"; say "disabled: stock COSMIC greeter will be used" ;;
enable)  rm -f "$JFG_ETC/disabled" "$JFG_ETC/broken"; jfg_reset_fails; "$JFG_LIB/heal" manual; cat "$JFG_STATUS" ;;
rebuild) extract_rootfs; "$JFG_LIB/heal" manual; cat "$JFG_STATUS" ;;
*) echo "usage: $0 install|uninstall|enable|disable|rebuild"; exit 2 ;;
esac
