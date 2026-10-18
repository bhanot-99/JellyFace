# Shared by launch / enter / heal. Source it, don't run it.
JFG_LIB=/usr/local/lib/jellyface-greeter
JFG_OPT=/opt/jellyface-greeter
JFG_ROOTFS=$JFG_OPT/root
JFG_PRISTINE=$JFG_OPT/pristine          # root-owned known-good copy of every installed file (the healer restores from here)
JFG_VAR=/var/lib/jellyface-greeter
JFG_RUN=$JFG_VAR/run                    # the only part the greeter user can write
JFG_ETC=/etc/jellyface-greeter          # `disabled` = you turned it off, `broken` = the healer turned it off
JFG_STATUS=$JFG_VAR/STATUS              # human-readable state, shown by `jellyface greeter status`
JFG_LOG=/var/log/jellyface-greeter.log
JFG_GREETD_CONF=/etc/greetd/cosmic-greeter.toml
JFG_STOCK=/usr/bin/cosmic-greeter-start

# $JFG_RUN belongs to the greeter user, so root must never write or chown inside it: that user could have planted a
# symlink there (root would then overwrite, or hand over, any file on the system). Writing AS the greeter user means a
# symlink can only lead somewhere that user could already write.
jfg_reset_fails() { runuser -u cosmic-greeter -- sh -c 'echo 0 > "$1"' _ "$JFG_RUN/fails"; }

jfg_log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "${JFG_WHO:-?}" "$*" >> "$JFG_LOG" 2>/dev/null || true; }
