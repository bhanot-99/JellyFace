# Changelog

## Unreleased

### Features
- Dashboard calendar shows events: a dot under each day (tertiary = public holiday / festival) and the titles on hover. `jellyface agenda holidays <region>` adds Google's public holiday calendars, `agenda add-source` adds more iCal calendars; the Agenda card includes them too.
- Dynamic Island: iPhone-style rework — spring morph, empty idle pill, split dual-activity bubbles, timer / notification / mute / volume / charging activities, artwork-tinted cava equaliser and glow, blur+scale transitions, tap / long-press / swipe-up gestures. The idle clock is gone.
- `jellyface files install`: the yazi terminal file manager (no sudo; download checked against GitHub's SHA-256), the Nerd
  Font symbols for its icons, defaults tuned for Kitty's full-resolution previews (`config/yazi/`), a `magick` stand-in so
  HEIC/AVIF/JXL previews work with Ubuntu's ImageMagick 6, and a theme in the shell's colours that follows every palette
  change. Everything it adds is recorded for `jellyface revert-system`; a `theme.toml` of your own is never overwritten.
- Kitty follows the JellyFace theme too (set up by `jellyface files install`): `~/.config/kitty/jellyface-theme.conf`,
  included once from `kitty.conf` (your other settings untouched), is rewritten on every palette change and open Kitty
  windows reload it at once. The greyscale palettes get soft, readable hues for the 16 terminal colours. A palette change
  never creates these files by itself. Tests: `tests/terminal-themes.sh`.

### Security
- `jellyface mail` verifies the IMAP server's certificate and host name (Python's default `IMAP4_SSL` checks neither, so the
  app password could be read on the network path); its temp files are created 0600 and its requests have timeouts.
- Login screen: the root helper no longer writes or chowns inside the directory owned by the greeter user (a planted symlink
  could overwrite or take over any file), and the Arch userland the greeter runs in is mounted nosuid and started with
  `no_new_privs`. Re-run `jellyface greeter install` (the printed sudo command) to pick this up.
- Lock screen: consecutive wrong passwords wait 1, 1, 1, 2, 4 ... up to 30 seconds; a correct password is never delayed.
- Notifications render as plain text (no remote Markdown images) and only http(s) and mailto links open; the calculator
  escapes the expression it hands to fish; the weather location lookup uses HTTPS (ipwho.is) instead of plain-HTTP ip-api.com.

### Fixes
- Dynamic Island: a notification no longer sticks forever after the card was expanded during a media + notification split; the card's swipe-to-collapse no longer steals presses from the scrubber and buttons; notification text is shown as plain text; `expandKind timer` / `notif` do nothing when there is no timer or notification; hover opens the card after a 450 ms pause (was 200 ms) so taps and swipes on the pill still work.
- Dock: README now describes the real rule (hides while any window is open on the active workspace).
- `plymouth-dither-eye/install.sh` clears the old theme folder before copying.
- `jellyface mail`: no longer crashes when no password or account is set; uses IMAP UIDs (marking a message read could hit
  the wrong one after a deletion), opens the mailbox read-only (it used to expunge messages flagged for deletion), reads
  only the start of each message instead of downloading whole attachments, and no longer depends on the locale's month
  names. The password is asked for instead of being typed on the command line. No personal address is built in any more.
- Agenda: recurring events that started more than ~13 years ago (birthdays, anniversaries) were silently dropped;
  `webcal://` addresses work.
- Interface names and file paths are passed to `sh -c` as arguments instead of being pasted into the command line
  (VPN and network statistics, area-picker clipboard copy).
- A crashed window helper no longer leaves a stale "fullscreen" state that kept the bar hidden; the window helper
  forgets workspaces that were removed.
- Media artwork in a URL scheme Qt cannot load (`attachment:`) is ignored instead of logging warnings and showing a
  broken image.
- Dock: a cancelled drag keeps the new order; the Dynamic Island's buttons no longer shadow `Item.enabled`.
- `jellyface pop-all` reports an unreachable shell and waits exactly as long as the panels stay open.
- The Qt/Quickshell pin in the container is also added when `pacman.conf` has no commented `IgnorePkg` line.
- About page: removed the "CLI" row that never showed a version.

- `cosmic-dock` and `cosmic-panel` change only their own entry in COSMIC's panel list (each used to overwrite the other's
  setting); `autostart off` works on a fresh checkout; the notification shim no longer loops on a trailing flag and quotes
  its strings; unit and desktop files are quoted for paths with spaces.
- Agenda: repeating events keep their wall-clock time in their own time zone (they moved an hour across daylight saving),
  and a moved or cancelled single occurrence replaces that date instead of appearing twice.
- Clipboard history reads at most its size limit, survives damaged entries and deletes orphaned images.
- HTTP requests from the shell time out after 15 s and cap the response size (a stalled lookup left the weather stuck);
  copying a file onto itself no longer deletes it; the local lyrics search stops after 20,000 files.
- The clock ticks once a minute unless a seconds display is on; logs rotate while the shell runs.
- Greeter healer edits the current greetd config instead of restoring an old copy; rebuilds keep one previous userland.
- Popup notifications no longer read a null notification while they are torn down.
- Builds use `cargo --locked`, rustup is downloaded before it is run, and the shell version comes from this changelog.
- `shell/assets/pam.d/passwd` (generated per machine) is no longer tracked.

### Clean-up
- Removed the unused mail service (its dashboard widget was removed earlier) and stale comments; leftover upstream
  names (`caelestia-cli`, the upstream repository in User-Agent headers) now say JellyFace.

## 1.1.0 (2026-10-15)

Stability and polish release. No new features.

### Lock screen
- The lock screen now **stays on screen**: COSMIC's screen-off and idle-suspend timers are set to *never* by
  `jellyface cosmic-tweaks` (undo with `--revert`), so a locked screen no longer turns black after a few minutes.
- **Safety net:** if the shell stops or crashes while the screen is locked, COSMIC's own lock screen takes over at once.
  Before, the session stayed locked with nothing drawn to unlock it, and only a hard reboot helped.
- `jellyface stop` / `restart` refuse to run while the screen is locked (`JF_FORCE=1` overrides).

### Fixes and performance
- A JellyFace restart no longer bounces COSMIC's notification daemon, which restarted COSMIC's whole top panel and
  crashed its applets every time.
- The workspace and window helpers back off (up to once a minute) instead of being restarted every 2 s when the
  compositor doesn't offer their protocol.
- No more 44 "GlobalShortcut will not work" warnings at every start (the Hyprland-only shortcut objects are inert
  stand-ins; COSMIC shortcuts call `jellyface ipc`).

### Compatibility
- Qt and Quickshell are pinned inside the container, so a container upgrade can't break the compiled shell plugin.
- `jellyface doctor` also checks the pin, COSMIC's lock-screen fallback and the always-on lock screen setting.

### Clean-up and documentation
- Removed upstream CI, Nix and editor files, the stale port patch and build caches.
- New README, architecture notes, security notes; JellyFace's own code is now MIT-licensed (`shell/` stays GPL-3.0).

## 1.0.0 (2026-10-14)

First release: the shell ported from Hyprland to COSMIC, COSMIC workspaces and windows, systemd service, native
COSMIC applet, wallpaper palettes and frosted glass, dock, JellyPanel, clipboard history, focus mode, agenda card,
lock screen with host password check, optional login screen.
