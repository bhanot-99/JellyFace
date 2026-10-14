# Changelog

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
