#!/usr/bin/env bash
# Headless test of the greeter UI against a fake greetd: no window opens, nothing touches the real login.
# usage: tests/greeter-ui.sh [shot.png]
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; . "$here/scripts/lib.sh"
shot="${1:-${TMPDIR:-/tmp}/jf-greeter-shot.png}"; sock="${TMPDIR:-/tmp}/jf-mock-greetd.$$"
"$here/greeter/stage.sh" >/dev/null
python3 "$here/tests/mock-greetd.py" "$sock" test > "$sock.log" 2>&1 & mpid=$!
sleep 0.5
for pw in test wrong; do
  rm -f "$shot"
  in_container "env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software JF_GREETER_TEST=1 JF_GREETER_W=1920 JF_GREETER_H=1080 JF_GREETER_DATA='$here/.greeter-data' GREETD_SOCK='$sock' JF_GREETER_TEST_PW=$pw JF_GREETER_SHOT='$shot.$pw.png' timeout 15 quickshell -p '$here/greeter' 2>&1 | grep -iE 'error|warn|fail' | grep -v 'Could not find' | head"
done
kill $mpid 2>/dev/null
echo "--- mock greetd saw:"; cat "$sock.log"; ls -la "$shot".*.png 2>&1
