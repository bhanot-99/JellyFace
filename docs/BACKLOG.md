# Backlog: known issues not fixed yet

Found in the October 2026 audit and the 1.1.0 release pass, and **not** fixed. What was fixed is in `CHANGELOG.md`.
File and line references may have moved; check them before relying on them.

## Needs your action first

- **Re-install the login screen:** `jellyface greeter install` prints a sudo command. The greeter fixes (symlink escalation,
  nosuid + no_new_privs, healer changes) need root and were only checked for syntax and wiring, never run as root. After
  installing, check `jellyface greeter status` and do a real logout/login.
- **Check by hand in the live shell:** the weather lookup and the calculator were not exercised in the 1.1.0 pass (popup
  notifications, the clock, panels, the island and window/workspace switching were). `Time.qml` reads `GlobalConfig`, so a
  per-screen override of `showSeconds` would not tick every second.
- **Remove the old Hunt Showdown boot theme from the system:**
  `sudo rm -rf /usr/share/plymouth/themes/hunt-showdown && sudo update-initramfs -u`. The boot theme itself is already back
  to `pop-basic`. `plymouth-dither-eye/` is still in the repo and installed.

## Security and privacy

| Item | Where | Why it was left | Suggested fix |
|---|---|---|---|
| Wi-Fi passwords are `nmcli` arguments, visible in `ps` for the life of the command | `shell/services/Nmcli.qml` (`connectWireless`, `createConnectionWithPassword`, the add-profile call) | `nmcli` only accepts the password as an argument; `--ask` opens a wizard that breaks `connection add`. An env-var wrapper was tried and reverted: it only moves the exposure into `nmcli`'s own process. | Talk to NetworkManager over D-Bus (`AddAndActivateConnection`, the password goes in the message body), e.g. `Quickshell.Networking` or gdbus with the value on stdin. It is a rewrite of the connect path. |
| Unpinned supply chain | `scripts/install.sh` (`quickshell-git`, `qt6-m3shapes-git`, `libcava` via AUR, `yay-bin` built with makepkg, image `arch-toolbox:latest`) | Pinning needs commits or digests you choose. | Pin AUR packages to the tested revisions (`doctor` names `4f508be`) and the image to a digest. |
| App password stored in plain text in `~/.config/jellyface/mail.json` (mode 0600) | `scripts/mail.py` | Only matters if mail is kept. | Use the Secret Service / keyring. |
| Privacy by default | `lyrics.cpp` sends artist/title to lrclib.net and music.163.com; the default weather lookup sends your public IP to ipwho.is; `greeter/stage.sh` asks open-meteo (now at most every 30 min) | Features, not bugs. | Make them opt-in, or add a "privacy" switch in settings. |
| Clipboard history is plain text with no expiry | `scripts/clipboard-store.py` | Product decision. | Optional expiry for unpinned entries; ignore chosen apps. |
| `/tmp` fallbacks when `XDG_RUNTIME_DIR` is unset | `scripts/lib.sh`, `bin/jellyface`, `scripts/run.sh`, `modules/lock/Lock.qml` (flag file), `scripts/greeter.sh` (`jf-mock.sock`) | `XDG_RUNTIME_DIR` is always set in a COSMIC session, and the QML side cannot know the uid. | Use `/tmp/jellyface-$UID` (0700) everywhere, QML included. |
| `greeter.sh window` builds a `bash -c` string from paths | `scripts/greeter.sh` | Test-only helper. | Pass paths as arguments. |
| `jellyface ipc lock unlock` unlocks without a password | `shell/modules/lock/Lock.qml` (IPC `unlock`) | Any process of yours can already do a lot; kept for scripts and tests. | Remove it or require the password. |

## Dead code and leftovers

- **Hyprland layer** (about 650 lines of C++ plus about 20 QML files): `shell/services/Hypr.qml`,
  `plugin/.../Services/hyprextras.*`, `hyprdevices.*`, and users in `modules/bar/**`, `modules/windowinfo/**`,
  `modules/lock/center/StateMessage.qml`, `modules/IdleMonitors.qml`, `modules/drawers/ContentWindow.qml`,
  `services/ShellState.qml`, `services/GameMode.qml`, `services/Brightness.qml`, `services/Colours.qml`.
  Effects on COSMIC: caps-lock, num-lock and keyboard-layout indicators can never work; idle screen-off sends `dpms` to a
  compositor that is not there; two `$HYPRLAND_INSTANCE_SIGNATURE` warnings at every start (the focus-grab and
  global-shortcut warnings are gone). Left because it cannot be tested without running the shell.
  Plan: replace each use with the COSMIC window/workspace data (`CosmicWindows`, `CosmicWs`) or delete it, one module at a time.
- **`scripts/mail.py` and `jellyface mail`** (617 lines): nothing in the QML reads `mail.json` or the
  `__JELLYFACE_MAIL_JSON__` marker. The CHANGELOG says the mail service was removed. Decide: delete, or wire it back in.
- **Duplicated work:** `helpers/cosmic-ws/wsd.c` repeats the workspace tracking that `helpers/cosmic-windows/wind.c` already
  does, so two compositor connections run (merge them); `scripts/theme.py` has two near-identical image loaders
  (`image_pixels`, `image_grid`); `Time.seconds` and `Time.enabled` are unused.
- **Cosmetic:** 137 QML ordering violations from `shell/scripts/qml-lint-conventions.py`.

## Bugs and rough edges still open

- **Keyboard-layout popout and area picker call `hyprctl`** (`modules/bar/popouts/kblayout/KbLayoutModel.qml`,
  `modules/areapicker/Picker.qml`). Not reachable with the default config (the kb-layout status icon is off, screenshots use
  `cosmic-screenshot`); part of the Hyprland layer below.
- **`modules/launcher/services/Schemes.qml`** runs `jellyface scheme get`, which the CLI does not have (upstream's
  `caelestia scheme`); the launcher's scheme mode lists nothing.
- **Notification formatting:** bodies are now plain text, so apps that send Markdown lose their formatting. A safe version
  would strip images and allow only a small set of tags.
- **Local lyrics search** still runs on the UI thread (now capped at 20,000 files, no symlinks); move it to `QtConcurrent`.
- **Dynamic Island:** the connecting neck between split bubbles ignores the tuck/drag transform (visible when the dashboard
  opens during a split); the expanded card heights 166 / 118 / 112 are repeated in several places (shared constants or a card
  component).
- **Dock** hides for a window on any monitor (multi-monitor setups); accepted for now.
- **`wsd` / `wind`:** `activate <index>` can race a workspace change; `MAXWS` 64 and `MAXWIN` 256 drop extras silently; window
  titles with invalid UTF-8 are passed through unchanged.
- **Theme watcher** (`scripts/theme.py watch`) polls every 2 s; use inotify.
- **Each clipboard copy** starts Python plus three subprocesses.
- **Greeter:** the heartbeat spawns `touch` every 1.5 s while the login screen is up.
- **Lock race, seen once:** in the first of five tests, JellyFace's lock dropped when COSMIC's locker was asked to lock
  (`loginctl lock-session`) while JellyFace held it; the screen ended up unlocked. Not reproduced in four more runs.
  Suspend from outside JellyFace (COSMIC's power menu, `systemctl suspend`) still races and shows COSMIC's lock screen.

## Not part of the audit but still open

- **Boot animation:** the user asked for a custom animation, then wanted the default Pop!_OS one back. A video was pointed
  at (`~/Downloads/From Klickpin.com- Golden seasonal ...mp4`): it is two anime eyes (red Sharingan, then purple Rinnegan)
  on black, 736x414, 14.9 s, not the "golden outdoor scenes" its name says. 447 frames were extracted at 30 fps into the
  session scratchpad (temporary, may be gone). Nothing was built from it. If it comes back: crop to the eye band, fit to
  screen width, loop one 7.3 s cycle, and keep PNGs small (the dithered style from the second attempt was about 5 MB for 90
  frames; the first attempt was 160 MB).
- **`.git` is about 70 MB** because the removed Hunt Showdown frames are still in history. Shrinking it means rewriting history.
- **All published artifacts were deleted** at the user's request; nothing depends on them.
