# JellyFace

A polished desktop shell for **COSMIC on Pop!_OS**: a slim left bar with a ghost logo and real workspace
switcher, a slide-down dashboard (weather, media, performance), an app launcher, and a greyscale theme.

JellyFace is a port of the [Caelestia](https://github.com/caelestia-dots/shell) shell (built with
[Quickshell](https://quickshell.org)), which was written for Hyprland, to run on COSMIC.

> **Status: prototype.** It runs daily on one machine (Pop!_OS 24.04, COSMIC, NVIDIA hybrid laptop).
> `jellyface install` has not yet been run end-to-end on a clean machine, so expect rough edges on a fresh
> install. See [Known limitations](#known-limitations).

## Requirements

- **Pop!_OS 24.04 LTS with the COSMIC desktop**, logged in to a COSMIC (Wayland) session
- About **6 GB** of free disk space (container, packages and build files)
- An internet connection for the first install
- Host packages: `distrobox`, `podman`, and a C toolchain for the small workspace helper

```bash
sudo apt install distrobox podman build-essential libwayland-dev libwayland-bin
```

## Install

```bash
git clone <this repository> ~/JellyFace      # or copy the folder to ~/JellyFace
cd ~/JellyFace
bin/jellyface install
```

`install` does the following, and is safe to run again:

1. Creates an Arch Linux **distrobox container** named `jellyface` (set `JF_CONTAINER` to change the name).
2. Installs Quickshell, Qt 6 and the other dependencies inside the container. It asks for your sudo
   password *inside the container*. It does not touch your Pop!_OS packages.
3. Builds the workspace helper (on the host) and the shell's native plugin (in the container).
   The plugin build takes a few minutes.
4. Copies the default configuration to `~/.config/caelestia/` and `~/.local/state/caelestia/`.
   Existing files are first copied to `backups/`.

Optional but recommended: put the launcher in your PATH.

```bash
ln -s ~/JellyFace/bin/jellyface ~/.local/bin/jellyface
```

## First run

Start with a timeout the first time, so the shell stops by itself if anything goes wrong:

```bash
jellyface start --timeout 120
```

You should see the bar on the left. Then run `jellyface doctor` to verify the setup.

COSMIC's own top panel may sit on top of JellyFace's drop-downs. To make it auto-hide (your original
panel settings are backed up first):

```bash
jellyface cosmic-tweaks            # undo with:  jellyface cosmic-tweaks --revert
```

To start JellyFace at every login:

```bash
jellyface autostart on             # undo with:  jellyface autostart off
```

## Making it part of your COSMIC session

JellyFace runs as a layer on top of COSMIC, so `jellyface integrate` wires it into the session properly. It shows
the plan, asks first, and changes only things in your own account:

```bash
jellyface integrate           # service + panel/lock + native applet + COSMIC theming, after a confirmation
jellyface revert-system       # undo everything it changed (restores your original COSMIC settings)
jellyface revert-system --list
```

| What | How |
|---|---|
| **Starts with the session** | A systemd *user* service (`jellyface service on|off|status`) tied to COSMIC's graphical session. It restarts on failure and stops after 5 failures in 5 minutes instead of looping. |
| **Real window information** | `helpers/cosmic-windows` reads COSMIC's window list through its own protocol. The bar's label and icon show the focused app, and the bar hides for fullscreen windows. |
| **COSMIC's apps follow the palette** | `jellyface theme system on|off`. The wallpaper palette is also written into COSMIC's own theme, so Files, Terminal and Settings match (windows that are already open pick it up the next time they start). Only keys your COSMIC already uses are written. |
| **JellyFace's own lock screen** | `Super+L` (and 3 minutes without input) opens JellyFace's lock screen, which checks your real login password (see "Lock screen" below). COSMIC's own lock (`Super+Escape`) is untouched and still available. |
| **A native COSMIC applet** | `jellyface applet install` then `jellyface applet panel-add` puts a ghost button in COSMIC's *own* panel (written in Rust with COSMIC's toolkit). Its menu opens the launcher, dashboard and notifications, locks the screen, shows the current theme and switches wallpaper-following and COSMIC theming on or off. `jellyface applet panel-remove` takes it out again. |

Safety: every file changed outside `~/JellyFace` is recorded with a copy of the original in `backups/`, nothing under
`/usr` or `/etc` is touched, and no `sudo` is used. The Rust toolchain used for the theme tool and the applet is
installed **inside the project** (`.rust/`, about 600 MB, safe to delete) and the build uses small project-local
stand-ins instead of installing system development packages.

## Using it

| Do this | To get this |
|---|---|
| Click the **ghost** | Open or close the app launcher (type to search, Enter to launch) |
| Click a **number** in the workspace pill | Switch to that COSMIC workspace |
| Move the cursor to the **top edge** | Slide down the dashboard (Dashboard, Media, Performance, Weather tabs) |
| Click the **clock, Wi-Fi, Bluetooth, sound** icons | Open their pop-outs |
| Click the **bell** icon above the power icon | Open or close the notification sidebar (click it again to close) |
| Click the **power** icon at the bottom | Open or close the session menu (power off, restart, log out) |
| **Click anywhere outside** an open launcher, session menu or sidebar | Close it (that click only closes the panel; it is not passed to the app underneath) |
| Press **Super + L** | Lock the screen with JellyFace's lock screen (enter your login password to unlock). Added by `jellyface cosmic-tweaks`; it replaces COSMIC's default Super+L ("focus window right"). |
| Press **Escape** while a panel is open | Close the launcher, session menu, sidebar or dashboard |

Everything can also be driven from the command line:

```bash
jellyface ipc drawers toggle launcher      # also: dashboard, sidebar, session, utilities, bar, osd
jellyface status | stop | restart
```

To open the launcher with a keyboard shortcut, add a custom shortcut in
**COSMIC Settings -> Keyboard -> Custom shortcuts** with the command
`~/JellyFace/bin/jellyface ipc drawers toggle launcher`.

## Customising

Edit these files, and the shell reloads them (restart it if a change doesn't show):

| File | What it controls |
|---|---|
| `~/.config/caelestia/shell.json` | Behaviour: border rounding, weather location and unit, which bar entries and pop-outs are on |
| `~/.config/caelestia/shell-tokens.json` | Sizes: the dashboard and its cards, and other component dimensions |
| `~/.local/state/caelestia/scheme.json` | Colours. Written automatically from your wallpaper (see above); edit by hand only with `jellyface theme auto off` |

Defaults live in `config/`. Examples:

```jsonc
// shell.json: pick your own weather location (a city name or "lat,lon") and unit
{ "services": { "weatherLocation": "30.70547,76.22196", "weatherUnits": "Celsius" } }
```

The wallpaper feature of Caelestia is switched off on purpose: JellyFace leaves your COSMIC wallpaper alone.

## Wallpaper-driven colour themes

The whole shell (bar, drawers, lock screen) takes its colours from a palette chosen to match your wallpaper.
Palettes come from the packs in `Color_Palette/*.txt` (100 sets of 5 swatches: Deepest, Dark Base, Mid Tone,
Surface, Highlight). When you change the wallpaper in COSMIC Settings, the new palette is applied within a few
seconds, with no restart.

How a palette is chosen: the wallpaper is reduced to a 5-step tonal ramp (darkest to lightest 20% of its pixels,
in CIELAB colour). Each palette's 5 swatches are compared with it step by step on hue and colour strength, plus a small
overall-brightness term, and the closest palette wins. Text colours are lightened if needed to keep strong contrast
(at least 7:1 for main text) on the palette's background.

```bash
jellyface theme match            # show the 5 best palettes for the current wallpaper (changes nothing)
jellyface theme match photo.jpg  # ...or for any image
jellyface theme apply            # apply the best match now
jellyface theme apply 37         # force a palette (by number or name); turns automatic theming off
jellyface theme apply grey       # the original grey scheme, applied exactly as shipped (palette 000)
jellyface theme tint [0-6]       # how strongly palette colours show (default 3; 1 = palette exactly as written)
jellyface theme soft [0-2]       # background lightness (default 0.7; 0 = near-black, 2 = much lighter)
jellyface theme auto on|off      # follow the wallpaper (on) or keep the current palette (off)
jellyface theme list | status
```

The palettes in the pack are near-greys with only a faint tint, so by default their colour is strengthened (`tint`) and
their backgrounds are lifted from near-black to a softer tinted mid-dark (`soft`), for every pack palette. The built-in
**Original Grey** (palette 000, from `config/scheme.json`) is the one exception: it is never tinted or softened.

To add palettes, drop another `.txt` file with the same layout into `Color_Palette/`. Needs `python3-gi`
(preinstalled on Pop!_OS). With a wallpaper folder (slideshow), COSMIC does not say which image is showing, so the
first image of the folder is used.

## Lock screen

`Super + L` (added by `jellyface cosmic-tweaks`) or 3 minutes without input locks the screen with JellyFace's own
lock screen (COSMIC's own lock, `Super+Escape`, keeps working too). It checks the password you type against your **real host login password** (the container's own account
has no password, so `scripts/pam-host-check.sh` asks the host's `unix_chkpwd`). It fails closed: any error rejects the
password. `jellyface doctor` verifies that a wrong password is rejected. If you ever get stuck on it, switch to a
text console (`Ctrl+Alt+F3`), log in, and run `jellyface ipc lock unlock`.

## Screen recording

The sidebar's **Screen recorder** card has an **Open Kooha** button. [Kooha](https://github.com/SeaDve/Kooha) is a
Flatpak that records through COSMIC's screen-cast portal; `jellyface install` installs it for you. Start, stop and
pause happen in Kooha's own window, because Kooha cannot be remote-controlled. Recordings are saved to
`~/Videos/Recordings/` and listed in the card.

## Icons

The shell runs in a container, so `jellyface start` points it at your host's icon theme (read from your COSMIC
settings) and at the host's apps and Flatpak exports. Some apps still ask for a tray icon by a name nobody ships,
for example Flatpak VLC asks for `vlc` but exports `org.videolan.VLC`. That shows as a pink/black checkerboard.
Add a line to `config/icon-aliases.txt` (`<name asked for>  <name that exists>`) and run `jellyface fix-icons`.
The log line `Could not load icon "<name>"` in `logs/jellyface.log` tells you the name the app asked for.

## Reliability

- `jellyface start` runs a small **supervisor**: if the shell crashes it is restarted automatically (it gives up after
  5 crashes in a row right after launch, so a bad build can never loop forever). Only one instance can run at a time.
- At login the supervisor waits until the COSMIC session is ready, so `jellyface autostart on` is safe across reboots.
- A broken `shell.json`, `shell-tokens.json` or `scheme.json` never prevents startup: the bad file is copied to
  `backups/` and the default is restored.
- The workspace helper exits by itself when the shell or the compositor goes away, so nothing is left behind.
- `logs/jellyface.log` is rotated at 5 MB (one previous generation is kept).

Run the stability suite after any change (about 5 minutes; it stops and restarts the shell several times):

```bash
tests/stability.sh            # add --quick for a 1-minute version
```

It checks clean start, double start, crash recovery, helper respawn, repeated stop/start cycles, invalid config,
a cold container (as after a reboot), 125 drawer toggles with a scan for QML runtime errors, and memory growth.

## Known limitations

JellyFace gets less information from COSMIC than Caelestia gets from Hyprland. Some features can't work yet:

- **Window thumbnails and window actions** (the live preview in the active-window pop-out, "detach") need a Hyprland-only
  capture feature and are not available.
- **Fullscreen** hides JellyFace only for a fullscreen window on the workspace you are looking at; a fullscreen video on another workspace does not hide it.
- **COSMIC's window outline** (the accent-coloured frame) is drawn by the compositor, which seems to read its colour at
  login: log out and in once after the first `jellyface theme system on`.
- **Workspace pill** shows numbers only, with no per-workspace app icons.
- **Global shortcuts.** Caelestia's built-in hotkeys need Hyprland; use COSMIC custom shortcuts and
  `jellyface ipc` instead.
- **Screen recording** is started and stopped in Kooha's own window, not from the sidebar card.
- **Notifications.** COSMIC already owns the notification service, so Caelestia's notification pop-ups are inactive.
- **Single screen.** All workspaces are treated as one group; multi-monitor setups are untested.

## Troubleshooting

- **Screen turned grey and needed a hard restart.** Seen once during development, right after a NVIDIA driver
  update that had not been rebooted into. If `nvidia-smi` prints "API mismatch", reboot first. Always try new
  builds with `jellyface start --timeout 120`. If the screen freezes, switch to a TTY (`Ctrl+Alt+F3`), log in,
  and run `jellyface stop`.
- **Clicks don't reach windows near the screen edges.** Run `jellyface doctor`, then `jellyface restart`.
- **Weather shows `--`.** The weather service was unreachable. Wait a moment and restart; check the internet connection.
- **Logs:** `~/JellyFace/logs/jellyface.log` (runtime) and `logs/build.log` (build).
- **Rebuild from scratch:** delete `.build/` and `.install/`, then `jellyface build`.

## Uninstall

```bash
jellyface stop && jellyface autostart off
distrobox rm --force jellyface            # removes the container (name may differ, see .env.local)
rm -rf ~/JellyFace                        # keep backups/ if you want to keep your saved settings
```

To put back COSMIC's panel settings: `jellyface cosmic-tweaks --revert`, or copy a folder from `backups/`.

## Layout, credits and licence

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the folder structure and the exact list of changes from upstream.

JellyFace is based on [Caelestia shell](https://github.com/caelestia-dots/shell) by the caelestia-dots contributors
(upstream commit recorded in `shell/UPSTREAM`) and runs on [Quickshell](https://quickshell.org).
Licensed under the **GNU GPL v3** (see `LICENSE`), the same as upstream.
