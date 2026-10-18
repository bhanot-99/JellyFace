# Changelog

## Unreleased

### Fixes
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
