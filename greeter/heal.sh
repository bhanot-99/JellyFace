#!/bin/bash
# The healer (root). Started (a) by jellyface-greeter-heal.path whenever the launcher drops heal-request, and
# (b) once at every boot (jellyface-greeter-heal.service). It repairs what it can, proves the greeter loads, and either
# re-enables it or marks it `broken` (-> stock COSMIC greeter) with a plain-English reason in STATUS.
set -u
. /usr/local/lib/jellyface-greeter/common.sh
JFG_WHO=heal
umask 022
status() { printf '%s\n%s\n' "$1" "$(date '+%F %T')" > "$JFG_STATUS"; chmod 644 "$JFG_STATUS"; jfg_log "STATUS: $1"; }
mkdir -p "$JFG_ETC"
rm -f "$JFG_RUN/heal-request"
jfg_log "healer started (${1:-auto})"
[ -e "$JFG_ETC/disabled" ] && { status "OFF: disabled by you (jellyface greeter enable to turn it on)"; exit 0; }

fixed=()
# 1. installed files vs the pristine root-owned copies
declare -A dest=([launch]=$JFG_LIB/launch [enter]=$JFG_LIB/enter [heal]=$JFG_LIB/heal [common.sh]=$JFG_LIB/common.sh)
for f in "${!dest[@]}"; do
    if [ -f "$JFG_PRISTINE/$f" ] && ! cmp -s "$JFG_PRISTINE/$f" "${dest[$f]}"; then
        install -m 755 -o root -g root "$JFG_PRISTINE/$f" "${dest[$f]}" && fixed+=("restored $f")
    fi
done
if [ -d "$JFG_PRISTINE/qml" ] && ! diff -rq "$JFG_PRISTINE/qml" "$JFG_OPT/qml" >/dev/null 2>&1; then
    rm -rf "$JFG_OPT/qml"; cp -a "$JFG_PRISTINE/qml" "$JFG_OPT/qml" && fixed+=("restored qml")
fi

# 2. runtime dirs and permissions
install -d -m 755 -o root -g root "$JFG_VAR"
install -d -m 755 -o cosmic-greeter -g cosmic-greeter "$JFG_RUN"
[ -d "$JFG_VAR/data" ] || install -d -m 755 -o "$(cat "$JFG_PRISTINE/owner" 2>/dev/null || echo root)" "$JFG_VAR/data"

# 3. sudoers: must be valid, or sudo breaks for the whole machine
sf=/etc/sudoers.d/jellyface-greeter
if [ -f "$sf" ] && ! visudo -cf "$sf" >/dev/null 2>&1; then
    mv "$sf" "$sf.bad.$(date +%s)"; fixed+=("moved invalid sudoers aside")
fi
if [ ! -f "$sf" ] && [ -f "$JFG_PRISTINE/sudoers" ] && visudo -cf "$JFG_PRISTINE/sudoers" >/dev/null 2>&1; then
    install -m 440 -o root -g root "$JFG_PRISTINE/sudoers" "$sf" && fixed+=("restored sudoers")
fi

# 4. greetd must point at the launcher (an OS update may have rewritten the stock config)
if ! grep -q "^command = \"$JFG_LIB/launch\"" "$JFG_GREETD_CONF" 2>/dev/null; then
    if [ -f "$JFG_PRISTINE/cosmic-greeter.toml" ]; then
        cp -a "$JFG_GREETD_CONF" "$JFG_GREETD_CONF.before-heal.$(date +%s)" 2>/dev/null
        install -m 644 -o root -g root "$JFG_PRISTINE/cosmic-greeter.toml" "$JFG_GREETD_CONF" && fixed+=("re-pointed greetd at launcher")
    fi
fi

# 5. the userland copy must run
if ! chroot "$JFG_ROOTFS" /usr/bin/quickshell --version >/dev/null 2>&1; then
    touch "$JFG_ETC/broken"
    status "FALLBACK: the Arch userland copy is missing or broken. Fix: jellyface greeter rebuild (then sudo command it prints)"
    exit 1
fi

# 6. prove the greeter really loads (headless, ~8s)
out=$("$JFG_LIB/enter" --smoke 2>&1); rc=$?
if [ "$rc" -eq 124 ] && ! printf '%s' "$out" | grep -qiE 'failed to load configuration|error'; then
    rm -f "$JFG_ETC/broken"; echo 0 > "$JFG_RUN/fails"; chown cosmic-greeter: "$JFG_RUN/fails"
    status "OK: JellyFace greeter active${fixed:+ (healed: ${fixed[*]})}"
    exit 0
fi
touch "$JFG_ETC/broken"
jfg_log "smoke test failed rc=$rc: $(printf '%s' "$out" | tail -5 | tr '\n' ' ')"
status "FALLBACK: greeter failed its load test (see $JFG_LOG). Stock COSMIC login is in use; nothing is locked out."
exit 1
