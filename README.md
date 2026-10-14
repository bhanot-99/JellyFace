<p align="center"><img src="assets/jellyface-app.svg" width="128" alt="JellyFace logo"></p>

# JellyFace

A desktop shell for **COSMIC on Pop!_OS**: a slim left bar with the JellyFace logo, real workspace switcher and the focused
app's name; a slide-down dashboard (weather, media, performance); an app launcher; a lock screen; and colours that follow
your wallpaper, from a pack of 100 palettes, across the shell **and** COSMIC's own apps.

JellyFace is a port of the [upstream](https://github.com/caelestia-dots/shell) shell (built with
[Quickshell](https://quickshell.org)), which was written for Hyprland, to run on COSMIC. It is wired into the COSMIC
session (systemd user service, a native panel applet, COSMIC theming) and every change it makes outside its own folder
can be undone with one command.

> **Status: 1.0, in daily use** on Pop!_OS 24.04 (COSMIC 1.10, NVIDIA hybrid laptop). `jellyface install` has not yet
> been run end-to-end on a clean machine, so expect rough edges on a fresh install. See
> [Known limitations](#known-limitations).

## Requirements

- **Pop!_OS 24.04 LTS with the COSMIC desktop**, logged in to a COSMIC (Wayland) session
- About **7 GB** of free disk space (container, packages, Rust toolchain and build files)
- An internet connection for the first install
- Host packages:

```bash
sudo apt install distrobox podman flatpak build-essential libwayland-dev libwayland-bin python3-gi gir1.2-gdkpixbuf-2.0
```

No other system packages are needed: the Rust toolchain is installed **inside the project** (`.rust/`, about 600 MB),
and nothing under `/usr` or `/etc` is modified. The one exception is the optional [login screen](#login-screen-optional),
which you install separately with `sudo`.

## Install

```bash
git clone https://github.com/bhanot-99/JellyFace ~/JellyFace
cd ~/JellyFace
bin/jellyface install                        # container, packages, build everything, default config, Kooha
ln -s ~/JellyFace/bin/jellyface ~/.local/bin/jellyface     # makes `jellyface` work from anywhere (the commands below assume it)
```

`install` is safe to run again. It:

1. Creates an Arch Linux **distrobox container** named `jellyface` (set `JF_CONTAINER` to change the name) and installs
   Quickshell, Qt 6 and the other dependencies *inside it* (it asks for your sudo password inside the container only).
2. Builds the two small C helpers (workspaces, windows), the shell's native plugin (in the container), the COSMIC
   theme tool and the native panel applet (Rust, project-local). Set `JF_SKIP_RUST=1` to skip the Rust parts.
3. Installs the default configuration where none exists yet (your own settings are kept when you re-run it;
   `JF_RESET_CONFIG=1 jellyface install` puts the defaults back, after copying your files to `backups/`) and
   **Kooha** (screen recorder, Flatpak).

The shell is tested with Quickshell 0.3.2 (`quickshell-git` revision `4f508be`). The installer takes the newest
`quickshell-git` from the AUR; if a later Quickshell breaks something, `jellyface doctor` shows which version you have.

Then try it safely, and make it part of your session:

```bash
jellyface start --timeout 120     # first run: stops by itself after 2 minutes if anything goes wrong
jellyface doctor                  # checks that everything is in place
jellyface integrate               # shows a plan and asks, then wires it into the COSMIC session (see below)
```

## Making it part of your COSMIC session

`jellyface integrate` shows what it will do, asks, and changes only things in your own account:

| What | How |
|---|---|
| **Starts with the session** | A systemd *user* service (`jellyface service on\|off\|status`) tied to COSMIC's graphical session. It restarts on failure and gives up after 5 failures in 5 minutes instead of looping. |
| **Real window information** | `helpers/cosmic-windows` reads COSMIC's window list and states through its own protocol. The bar shows the focused app's name and icon, and hides for a fullscreen window **on the workspace you are looking at** (a fullscreen video on another workspace does not hide it). |
| **COSMIC's own apps follow the palette** | `jellyface theme system on\|off`. The wallpaper palette is also written into COSMIC's theme, so Files, Terminal and Settings match. Windows that are already open pick it up the next time they start. Only keys your COSMIC already uses are written. |
| **A native COSMIC applet** | `jellyface applet install`, then `applet panel-add`, puts a JellyFace button in COSMIC's *own* panel (Rust + COSMIC's toolkit). Its menu opens the launcher, dashboard and notifications, locks the screen, shows the current theme and toggles wallpaper-following and COSMIC theming. COSMIC's panel auto-hides; move the cursor to the top edge to see it. |
| **Panel and shortcuts** | `jellyface cosmic-tweaks` makes COSMIC's top panel auto-hide (so it doesn't cover JellyFace's drop-downs) and adds **Super+L** (JellyFace's lock screen), **Super+V** (clipboard history) and **Super+Shift+F** (focus mode) as COSMIC custom shortcuts. Shortcuts you already have are kept; a key you already use is left alone. |

**Safety.** Every file changed outside `~/JellyFace` is recorded together with a copy of the original in `backups/`.
`jellyface revert-system` puts everything back (`--list` shows what would change). Nothing under `/usr` or `/etc` is
touched and no `sudo` is used on the host. Backups are never deleted automatically.

## Using it

| Do this | To get this |
|---|---|
| Click the **JellyFace logo** in the bar, or move the cursor to the **bottom edge** | Open the app launcher (type to search, Enter to launch) |
| Move the cursor to the **top edge** | Slide down the dashboard (Dashboard, Media, Performance, Weather) |
| Click a **number** in the workspace pill | Switch to that COSMIC workspace |
| Click the **clock, Wi-Fi, Bluetooth, sound** icons, or hover the app label | Open their pop-outs |
| Click the **bell** icon | Open or close the notification sidebar |
| Click the **power** icon | Open or close the session menu (power off, restart, log out) |
| **Click outside** an open launcher, session menu or sidebar, or press **Escape** | Close it (the click only closes the panel; it is not passed to the app underneath) |
| Press **Super + L** | Lock the screen with JellyFace's lock screen |

From the command line (or as COSMIC custom shortcuts under **Settings -> Keyboard**):

```bash
jellyface ipc drawers toggle launcher      # also: dashboard, sidebar, session, utilities, bar, osd
jellyface ipc drawers dashboardTab 1       # open the dashboard on a tab: 0 Dashboard, 1 Media, 2 Performance, 3 Weather
jellyface lock                             # JellyFace's lock screen
```

## Wallpaper-driven colour themes

The whole shell (bar, drawers, lock screen) takes its colours from a palette chosen to match your wallpaper. Palettes
come from the packs in `Color_Palette/*.txt` (100 sets of 5 swatches: Deepest, Dark Base, Mid Tone, Surface, Highlight).
When you change the wallpaper in COSMIC Settings, the new palette is applied within a few seconds, with no restart.

How a palette is chosen: the wallpaper is reduced to a 5-step tonal ramp (darkest to lightest 20% of its pixels, in
CIELAB colour). Each palette's 5 swatches are compared with it step by step on hue and colour strength, plus a small
overall-brightness term, and the closest palette wins. Text colours are lightened if needed to keep at least 7:1
contrast on the palette's background.

```bash
jellyface theme match            # show the 5 best palettes for the current wallpaper (changes nothing)
jellyface theme match photo.jpg  # ...or for any image
jellyface theme apply            # apply the best match now
jellyface theme apply 37         # force a palette (number or name); turns automatic theming off
jellyface theme apply grey       # the original grey scheme, applied exactly as shipped (palette 000)
jellyface theme tint [0-6]       # how strongly palette colours show (default 3; 1 = palette exactly as written)
jellyface theme soft [0-2]       # background lightness (default 0.7; 0 = near-black, 2 = much lighter)
jellyface theme system on|off    # also theme COSMIC's own apps (default on)
jellyface theme auto on|off      # follow the wallpaper (on) or keep the current palette (off)
jellyface theme list | status
```

The pack's palettes are near-greys with a faint tint, so by default their colour is strengthened (`tint`) and their
backgrounds lifted from near-black to a soft tinted mid-dark (`soft`). The built-in **Original Grey** (palette 000) is
the one exception: it is never tinted or softened. To add palettes, drop another `.txt` file with the same layout into
`Color_Palette/`. With a wallpaper folder (slideshow), COSMIC does not say which image is showing, so the first image of
the folder is used.

## Clipboard history, focus mode, agenda

| Do this | To get this |
|---|---|
| **Super + V** (or `jellyface ipc clipboard toggle`) | Clipboard history: type to search, arrows + Enter or a click copies an entry (then press Ctrl+V), pin or delete entries. Text and images are kept (last 50 plus pinned) in `~/.local/state/jellyface/clipboard/`; content marked sensitive by password managers is never stored. |
| **Super + Shift + F** (or `jellyface ipc focus toggle`) | Focus mode: Do Not Disturb on and the screen kept awake; turning it off restores both as they were. A target icon shows in the bar's status icons. |
| **Quick actions** (dashboard, bottom row) | Screenshot (`cosmic-screenshot`), Kooha, clipboard history, focus mode, keep awake |

**Agenda card.** A bento-style desktop card (top right, under all windows): a date tile, a "Next up" tile with a countdown,
and Today / Tomorrow tiles. To show your Google Calendar: Google Calendar on the web -> Settings -> your calendar ->
*Integrate calendar* -> **Secret address in iCal format**, then

```bash
jellyface agenda set "https://calendar.google.com/calendar/ical/.../basic.ics"   # keep this address private
jellyface agenda status
```

A local `.ics` file path works too. The card re-reads the calendar every 15 minutes; `"enabled": false` in
`~/.config/jellyface/desktop.json` hides it.

## Touchpad gestures

**Swipe up with three fingers** to open COSMIC's own workspace overview (the same as Super+W: live previews of your
windows and workspaces); **swipe down with three fingers** (or press Esc) to go back to your desktop. While you swipe
up, the desktop dims and shrinks with your fingers; let go after a short swipe or a flick and the overview opens, let go
earlier and it springs back.

JellyFace also has its own overview of the windows on the current workspace, as a grid of cards (app icon, name and
window title): `jellyface ipc overview toggle`. Click a card or press Enter to switch to that window, the x on a card
closes it, and Esc or a click outside closes the overview.

COSMIC keeps every swipe of three or more fingers to itself, so `helpers/gestures/gestured` reads the touchpad
directly on the host, next to COSMIC (which keeps its own four-finger workspace swipe). That needs read access to the
touchpad, given once by a udev rule (only the touchpad, only to whoever is logged in at the screen; keyboards stay
private). Gestures start working within half a minute, no restart needed:

```bash
sudo cp ~/JellyFace/config/udev/70-jellyface-touchpad.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=input --action=change
# undo: sudo rm /etc/udev/rules.d/70-jellyface-touchpad.rules, then the same two udevadm commands
```

`jellyface doctor` shows whether it works; `logs/gestures.log` lists each recognised swipe.

## Lock screen

`Super + L`, or 3 minutes without input, locks the screen with JellyFace's own lock screen (clock, weather, media,
system gauges, password box). COSMIC's own lock (`Super+Escape`) keeps working too. The password you type is checked
against your **real host login password**: the container's own account has no password, so `scripts/pam-host-check.sh`
asks the host's `unix_chkpwd`. It fails closed (any error rejects the password) and `jellyface doctor` verifies that a
wrong password is rejected. If you are ever stuck on it, switch to a text console (`Ctrl+Alt+F3`), log in, and run
`jellyface ipc lock unlock`.

## Login screen (optional)

`jellyface greeter` can also make JellyFace's lock-screen look your **login screen** (greetd + a copy of the
container's Arch userland under `/opt/jellyface-greeter`). Unlike everything else this needs `sudo` and changes
system files (`/etc/greetd/cosmic-greeter.toml`, `/etc/sudoers.d/jellyface-greeter`, two systemd units), so it is
never part of `install` or `integrate`.

```bash
jellyface greeter test        # headless load test; changes nothing
jellyface greeter window      # see it in a test window with a fake login (changes nothing)
jellyface greeter export      # pack the container's userland (.greeter-root.tar, about 4 GB) for the next step
jellyface greeter install     # prints the one sudo command to run
jellyface greeter status
jellyface greeter uninstall   # back to COSMIC's own login screen (prints the sudo command)
```

It is built to fail safe: the new login screen is only switched on after a headless load test passes, and if it ever
fails to start (or shows no sign of life within 30 s) COSMIC's stock login screen starts instead and a root "healer"
repairs or disables it. You can always log in.

## Screen recording

The sidebar's **Screen recorder** card has an **Open Kooha** button. [Kooha](https://github.com/SeaDve/Kooha) is a
Flatpak that records through COSMIC's screen-cast portal. Start, stop and pause happen in Kooha's own window (Kooha has
no remote-control interface). Recordings go to `~/Videos/Recordings/` and are listed in the card.

## Customising

| File | What it controls |
|---|---|
| `~/.config/jellyface/shell.json` | Behaviour: border rounding, weather location and unit, which bar entries and pop-outs are on |
| `~/.config/jellyface/shell-tokens.json` | Sizes: the dashboard and its cards, and other component dimensions |
| `~/.local/state/jellyface/scheme.json` | Colours. Written automatically from your wallpaper; edit by hand only with `jellyface theme auto off` |
| `config/icon-aliases.txt` | Tray icons that ask for a name nobody ships (see below) |

Defaults live in `config/`. For example, to pick your own weather location (a city or `"lat,lon"`) and unit:

```jsonc
// ~/.config/jellyface/shell.json
{ "services": { "weatherLocation": "30.70547,76.22196", "weatherUnits": "Celsius" } }
```

JellyFace draws no wallpaper, desktop clock, visualiser or desktop widgets of its own (the background layer and desktop
widgets were removed); your COSMIC wallpaper stays in charge, and JellyFace never changes it. There is no built-in file
manager either: use COSMIC Files.

**Icons.** JellyFace uses whatever icon theme your desktop uses (`gsettings get org.gnome.desktop.interface icon-theme`;
COSMIC's own setting is `~/.config/cosmic/com.system76.CosmicTk/v1/icon_theme`; set both to change it). The shell runs in a container, so `jellyface start` points it at your host's icon theme and at the host's
apps and Flatpak exports. Some apps still ask for a tray icon by a name nobody ships (Flatpak VLC asks for `vlc` but
exports `org.videolan.VLC`), which shows as a pink/black checkerboard. Add a line to `config/icon-aliases.txt`
(`<name asked for>  <name that exists>`) and run `jellyface fix-icons`. The log line `Could not load icon "<name>"` in
`logs/jellyface.log` tells you the name.

## Reliability

- `jellyface start` runs a **supervisor** that restarts the shell if it crashes (and gives up after 5 immediate crashes in
  a row). Only one instance can run at a time, and leftovers from a hard-killed supervisor are cleared at start.
- At login the supervisor waits until the COSMIC session is ready.
- A broken `shell.json`, `shell-tokens.json` or `scheme.json` never prevents startup: the bad file is copied to `backups/`
  and the default is restored.
- The two COSMIC helpers exit by themselves when the shell or the compositor goes away.
- `logs/jellyface.log` is rotated at 5 MB (one previous generation is kept).

```bash
tests/stability.sh            # about 5 minutes; --quick for 1 minute. Stops the service while it runs and restores it after.
```

It checks clean start, double start, crash recovery, helper respawn, repeated stop/start cycles, invalid config, a cold
container (as after a reboot), 125 drawer toggles with a scan for QML runtime errors, and memory growth.

## Known limitations

JellyFace gets less information from COSMIC than Jellyface gets from Hyprland.

- **Window thumbnails and "detach"** in the active-window pop-out need a Hyprland-only capture feature and are not available.
- **COSMIC's window outline** (the accent-coloured frame) is drawn by the compositor, which seems to read its colour at
  login: log out and in once after the first `jellyface theme system on`.
- **Workspace pill** shows numbers only, with no per-workspace app icons.
- **Global shortcuts.** Jellyface's built-in hotkeys need Hyprland; use COSMIC custom shortcuts and `jellyface ipc`.
- **Notifications.** JellyFace takes the notification service from `cosmic-notifications` while it runs (and gives it back when
  it stops), so notifications use JellyFace's own pop-ups and sidebar. Focus mode (`Super+Shift+F`) mutes them.
- **Screen recording** is controlled in Kooha's window, not from the sidebar card.
- **Transparency and blur** were tried and removed: at useful strengths they were barely visible over the wallpaper.
- **Single screen.** All workspaces are treated as one group; multi-monitor setups are untested.
- **Clean-machine install** is untested end to end.

## Troubleshooting

- **First step:** `jellyface doctor`. Runtime log (also when started by the service): `logs/jellyface.log`. Theme
  log: `logs/theme.log`. Service start/stop: `journalctl --user -u jellyface.service`.
- **Editing the QML.** Live reload on save is off by default (a half-saved file used to load a broken shell).
  Start with `JF_DEV=1 jellyface start` while you work on `shell/`.
- **Nothing is visible.** If a window on the current workspace is fullscreen (a video, for example), JellyFace hides on
  purpose; switch workspace or leave fullscreen. Otherwise run `jellyface status`, then `jellyface restart`.
- **The panel applet is not visible.** COSMIC's panel auto-hides: move the cursor to the top edge. Add it with
  `jellyface applet panel-add`.
- **Screen turned grey and needed a hard restart.** Seen once during development, right after an NVIDIA driver update
  that had not been rebooted into. If `nvidia-smi` prints "API mismatch", reboot first. Try new builds with
  `jellyface start --timeout 120`. If the screen freezes, switch to a TTY (`Ctrl+Alt+F3`), log in, run `jellyface stop`.
- **Weather shows `--`.** The weather service was unreachable. Wait a moment and restart; check the internet connection.
- **Rebuild from scratch:** delete `.build/` and `.install/`, then `jellyface build`.

## Command reference

```
jellyface install | build | doctor | help
jellyface start [--timeout N] [--foreground] | stop | restart | status   (through systemd when the service is on)
jellyface service on|off|status          start with the COSMIC session (systemd user service)
jellyface autostart on|off               lighter alternative: an XDG autostart entry
jellyface integrate [--yes]              service + panel/lock + applet + COSMIC theming, after a confirmation
jellyface revert-system [--list]         undo every change made outside ~/JellyFace
jellyface cosmic-tweaks [--revert]       auto-hide COSMIC's top panel; Super+L = JellyFace lock
jellyface applet install|panel-add|panel-remove|remove
jellyface theme apply|match|list|tint|soft|system|auto|status
jellyface lock                           JellyFace's lock screen
jellyface fix-icons                      create icon aliases from config/icon-aliases.txt
jellyface greeter test|window|export|install|uninstall|status   optional login screen (sudo, see above)
jellyface agenda set <ics|url> | status   calendar for the Agenda card
jellyface focus|tiling on|off|status     COSMIC focus-follows-cursor / auto-tiling
jellyface cosmic-dock hide|show|status   COSMIC's own dock
jellyface notify SUMMARY [BODY]          send a test notification
jellyface ipc <target> <function> [args]
```

## Uninstall

```bash
jellyface greeter uninstall               # only if you installed the login screen
jellyface revert-system                   # restores your COSMIC settings, removes the service, applet and theme files
distrobox rm --force jellyface            # removes the container (name may differ, see .env.local)
rm -rf ~/JellyFace                        # keep backups/ if you want to keep your saved settings
```

## Layout, credits and licence

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the folder structure and the exact list of changes from upstream.

JellyFace is based on [the upstream shell](https://github.com/caelestia-dots/shell) by the caelestia-dots contributors
(upstream commit recorded in `shell/UPSTREAM`) and runs on [Quickshell](https://quickshell.org). Licensed under the
**GNU GPL v3** (see `LICENSE`), the same as upstream.
