# New UI plan — codename "Drift" (working name)

Branch: `ui-redesign`. Status: **plan only, nothing built yet.**

A second, complete look for JellyFace that sits **next to** the current one ("Classic"). You choose one with
`jellyface ui drift|classic`. Classic keeps working unchanged and remains the default until Drift is finished.

Reference: six concept films for a fictional "Nava OS" (trailer, Control Center, Command Bar & Terminal,
Personalization, Motion, Dev Preview roadmap). Drift takes their **ideas** (calm pastel liquid glass, an interface that
appears when you call it, keyboard first, one motion curve). It does not copy their name, logo, artwork or exact
layouts.

---

## 1. Design principles

1. **Calm by default.** The resting desktop is just a wallpaper, a thin top bar and the dock. Everything else appears
   when you call it and leaves when you're done.
2. **Glass, not boxes.** Every surface is frosted glass over COSMIC's real blur, tinted by the wallpaper. Corners are
   large, shadows are soft, and borders are 1 px light rims.
3. **Expand in place.** A tile grows into its detail view from where it sits (Wi‑Fi tile → network list), and ‹ Back
   reverses the motion. No new windows, and no jumping from one layout to another.
4. **Keyboard first.** Every surface opens with one shortcut and works with arrows, Enter and Esc. Shortcuts are
   shown as keycap pills on screen.
5. **One motion system.** A single small set of curves and durations is used by every animation in Drift.
6. **Yours.** Light, Dark or Auto (sunset/sunrise), one accent colour, wallpaper moods, and glass strength. Every
   change applies live.

## 2. Visual foundations (the "tokens")

All of these live in one place (`shell/drift/theme/`), so a single change restyles everything.

| Area | Plan |
|---|---|
| **Palette, light** | Background mist `#EEF0F8`; glass white at 55–70 % over blur; text navy `#1B1F3B`; secondary `#5A6080`; pastels: ice `#A9C8F5`, rose `#F2B8CF`, peach `#F7C9A3`, lilac `#C4B5F2`, sage `#B5D9C4`. |
| **Palette, dark** | Deep indigo `#1C1B3A` → `#2A2660` gradient; glass navy at 55–70 %; text `#F2F3FA`; the same pastels, a little deeper. |
| **Accent** | One colour, indigo `#5B6CF0` by default. Choices are indigo, violet, pink, orange, green and graphite. It drives selection, toggles, sliders, the focus ring and the dock's running dot. |
| **Status colours** | Green for battery/OK, amber for warning, red for error. These never come from the accent. |
| **Glass** | Three tiers: *pane* (the panel body), *tile* (a card inside a pane) and *well* (a slider track or input). Two user dials: transparency and blur. |
| **Shape** | Radii: 28 for panes, 20 for tiles, 14 for rows, and fully rounded for pills, toggles and keycaps. The spacing scale is 4/8/12/16/24/32. |
| **Type** | Inter (Display 40/46, Title 22/28, Body 15/22, Caption 11/14) plus a monospace font for the small spaced-out labels (`02 — CONTROL CENTER`) and keycaps. |
| **Icons** | One stroke icon set (1.5 pt stroke, 24 grid). Material Symbols Rounded at weight 300 is already in the shell and is the closest fit. |
| **Motion** | `Drift.ease` = a soft ease-out with no overshoot, at 120 ms (micro), 220 ms (standard) and 380 ms (expand/collapse). Content inside a growing panel fades in with a 30 ms stagger per tile, as seen frame by frame in the reference. Only toggles and knobs get a small spring. |
| **Wallpaper** | Original "glass sails": layered translucent curved shapes drawn in QML/shaders, with six moods (Mist, Aurora, Dusk, Night, Blush, Mono). **Living** mode shifts their colours with the time of day: dawn, noon, golden hour, night. |

## 3. Surfaces: every screen in Drift

| # | Surface | How you open it | What it contains |
|---|---|---|---|
| 1 | **Desktop** | — | Living wallpaper (our own background layer) and the top bar and dock below. |
| 2 | **Top bar** | always shown (Full) or a clock only (Minimal) | Left: workspace dots and the focused app's name. Centre: a now-playing pill while media is playing. Right: a status pill (time · date · Wi‑Fi · battery). Clicking the right pill opens Control Center; clicking the time opens Today. |
| 3 | **Dock** | Always / Auto‑hide / Off | Glass capsule with app icons, a running dot and a hover label. Reuses the current `dock.json` and app launching. |
| 4 | **Control Center** | Super+C, click the status pill, or pull down from the top | A 2×2 tile grid: Connectivity (Wi‑Fi, Bluetooth) · Focus · sliders (volume, brightness) · quick toggles (Night light, Keep awake, Screen record, Settings) and the battery bar. Each tile **expands in place** into a detail view: Wi‑Fi networks and password · Bluetooth devices · Sound output device · Focus modes with an end time · Battery with a usage graph and Saver / Balanced / Performance (`system76-power`). Works fully from the keyboard (arrows, Enter, Esc). |
| 5 | **Command bar** | Super+Space (see §6) | One search for apps, open windows ("Current window"), Drift settings pages, actions (lock, sleep, restart shell), a calculator (`24*7`), unit conversion (`5 km in mi`) and files in the home folder. |
| 6 | **Window hints** | Super+J (toggle) | Every visible window gets a letter badge (A S D F…). Press the letter to jump to that window. |
| 7 | **Desks** (workspace overview) | Super+W | A row of desk cards showing **schematic** windows (app icon and title in the window's real position and size), the current desk highlighted, and arrows + Enter to switch. |
| 8 | **Clipboard** | Super+V | A carousel of cards (text, colour swatch, image). Arrow through it or type to filter; Enter pastes. Reuses the current clipboard history service. |
| 9 | **Notifications** | — | Glass toasts at the top right, plus a notification list inside Control Center. Focus mode holds them back. |
| 10 | **OSD** | volume/brightness keys | A small glass pill under the top bar with a slider and a % bubble. |
| 11 | **Today** | click the time | Calendar month, next events (current agenda sources), weather, media. |
| 12 | **Deep Focus** | Super+Shift+F (the current shortcut) | Do Not Disturb plus hidden dock and bar, a focus timer pill in the top bar, and notifications that wait for you. |
| 13 | **Appearance** (Drift Settings) | Command bar → "Appearance", or the CC gear | Sidebar: Theme (Light / Dark / Auto) · Accent · Wallpaper · Glass (transparency, blur, live preview) · Dock & bar · Keyboard (the shortcut sheet) · About · **Switch to Classic**. Every change is live. |
| 14 | **Keyboard sheet** | Super+/ (see §6) | Glass list of every Drift shortcut with keycaps. |
| 15 | **Session menu** | CC power button or command bar | Lock · Sleep · Restart · Shut down · Log out, as glass pills. |
| 16 | **Lock screen** | Super+L / idle / lid | A big thin clock, the date, a glass password pill, a media mini-player and the wallpaper blurred. **Same security code as Classic** (see §5). |
| 17 | **Login screen** (optional, last) | `jellyface greeter` | The lock look at login. Only after everything else is done. |

## 4. What is possible on COSMIC, and what is not

JellyFace is a Quickshell shell on top of COSMIC's compositor. That rule decides what Drift can do, and it is the
reason the earlier "Vessel" attempt felt fake. Planned around up front:

| Reference feature | Drift | Why |
|---|---|---|
| Glass, blur, all panels and their animations | **Full** | Our own layer surfaces; COSMIC blurs them (`BackgroundEffect`, already used). |
| Control Center, command bar, lock, notifications, settings | **Full** | Existing services: Nmcli, Bluetooth, Audio, Brightness, Notifs, Pam, Clipboard. |
| Window hints / jump to a window | **Full** | `wind` already reports each window's position/size and can `activate` it. |
| Hold Super to show hints | **Changed** | COSMIC shortcuts only fire on key press, and we never see a key release. Super+J toggles the hints instead. |
| Swap two windows (Super+Shift+letter) | **No** | We cannot move windows. Dropped. |
| Workspace overview with live thumbnails | **Schematic** | COSMIC gives no screen capture to clients. We draw window rectangles with app icons instead. |
| Tiling | **COSMIC's own** | COSMIC has auto-tiling (it's on, `autotile = true`). Drift adds a toggle for it in Control Center; it does not tile windows itself. |
| Deep focus making the window fullscreen | **Later** | Needs a new `fullscreen <id>` command in `wind` (the COSMIC protocol supports it). Optional. |
| Rewind (scrub your session back in time) | **No** | Windows can't be snapshotted or restored. Dropped. A possible stand-in is "Recently closed: reopen" in the command bar. |
| Window open/close/move animations | **No** | These belong to COSMIC. Drift's motion covers only Drift's own surfaces. |
| Light/Dark/Accent also applying to COSMIC apps | **Yes** | `tools/cosmic-theme` already writes COSMIC's theme; Drift feeds it its palette. |
| Night light | **Check first** | COSMIC has no built-in night light here, and gammastep/wlsunset aren't installed. Hidden until a working tool is chosen. |
| Package install from the command bar | **Later** | Possible through Flatpak search, but not a priority. |

## 5. Architecture: how Drift lives next to Classic

```
shell/
├── shell.qml              Classic entry point (unchanged)
├── drift.qml              Drift entry point (new)      ← run.sh starts one or the other
├── services/  utils/      shared as-is (audio, network, bluetooth, notifications, clipboard, windows, workspaces…)
├── modules/ components/   Classic only, untouched
└── drift/                 everything new
    ├── theme/             DriftTheme (palette, accent, light/dark/auto), Glass tiers, Motion, Type
    ├── components/        GlassPane, Tile, Pill, Keycap, Toggle, Slider, ListRow, Segmented, SearchField, Icon…
    ├── surfaces/          wallpaper, topbar, dock, controlcenter, commandbar, hints, desks, clipboard, notifications,
    │                      osd, today, focus, appearance, keyboard, session, lock
    └── DriftState.qml     which surface is open, the keyboard-focus owner, and the fast IPC socket
```

- **No Classic code is changed.** The only shared edits are additive: `run.sh` and `bin/jellyface` learn
  `ui drift|classic`, and `shell.json` gets `"ui": "classic"` (the default).
- **Shared services stay single.** The notification server, clipboard watcher, idle/lock monitors and the lock-safety
  flag (`jellyface-locked`) all run from the same singletons, so both UIs behave the same under the hood. Only one UI
  runs at a time.
- **The lock screen reuses Classic's security parts** (`WlSessionLock`, `Pam.qml`, the locked flag, `SleepGuard`,
  `IdleMonitors`). Drift only replaces what is drawn inside the lock surface. `tests/stability.sh` must pass in both
  modes.
- **Fast shortcuts.** One Drift socket (the same pattern as JellyPanel's, a few ms) handles `cc`, `bar`, `hints`, `desks`,
  `clipboard` and so on, instead of `quickshell ipc` (about 230 ms).
- **Shortcuts switch with the UI.** `jellyface ui drift` installs Drift's COSMIC custom shortcuts and `ui classic` puts
  Classic's back. Both are tracked by the existing `sys_track` / `revert-system`.
- **Settings.** Drift's own settings go in `~/.config/jellyface/drift.json` (theme, accent, wallpaper mood, glass,
  dock/bar mode), with defaults in `config/drift.json`. A broken file falls back to the defaults, as Classic does.

## 6. Shortcut map (Drift)

| Keys | Action | Conflict with COSMIC's defaults |
|---|---|---|
| Super+Space | Command bar | **Yes:** COSMIC uses it to switch keyboard layout. **Decided:** Drift takes it over and `ui classic` gives it back. |
| Super | (Classic: JellyPanel) | In Drift: also the command bar, or unused. **Decision needed.** |
| Super+C | Control Center | free |
| Super+J | Window hints | **Yes:** COSMIC uses it for Focus(Down) (vim-style). Alternative: Super+G. **Decision needed.** |
| Super+W | Desks overview | **Yes:** COSMIC's own workspace overview. Drift's would replace it. |
| Super+V | Clipboard | already JellyFace's |
| Super+Shift+F | Deep Focus | already JellyFace's |
| Super+L | Lock | already JellyFace's |
| Super+, | Appearance | free |
| Super+Shift+/ | Keyboard sheet | free |

## 7. Build order, with a checkpoint after every step

Lesson from Nocturne and Vessel: never build the whole thing in one go. Each step ends with something you can **see and
judge**, and work stops there until you say go.

| Step | Build | You judge |
|---|---|---|
| **0. Plumbing** | `drift.qml` entry, `jellyface ui drift/classic`, config file, theme/motion tokens, empty Drift that starts and stops cleanly; the stability suite runs in Drift mode. | Switching back and forth is safe. |
| **1. Style gallery** | A single "kitchen sink" window: palette in light and dark, every accent, the glass tiers over the real wallpaper, type scale, every component (tile, pill, toggle, slider, list row, segmented control, keycap, search field) and the motion curve playing. | **The look itself.** Nothing else is built until this is right. |
| **2. Desktop** | Living wallpaper (sails, six moods), top bar, dock. | The resting desktop. |
| **3. Control Center** | Grid, all drill-ins, keyboard navigation, OSD. | The signature interaction (expand in place). |
| **4. Command bar** | Search, windows, actions, calculator, units, keyboard sheet. | |
| **5. Notifications + Today + Session** | Toasts, list in CC, calendar/weather/media, power menu. | |
| **6. Appearance** | Theme / accent / wallpaper / glass / dock & bar, live; COSMIC theme sync; Auto by sunset. | "Make it yours" end to end. |
| **7. Keyboard layer** | Window hints, Desks overview, Clipboard carousel, Deep Focus. | |
| **8. Lock screen** | New look on the shared secure lock; idle, lid and suspend all tested. | |
| **9. Hardening** | Stability suite in both modes, `jellyface doctor` checks for Drift, frame timing (no dropped frames when panels open), memory, README/ARCHITECTURE/CHANGELOG. | Ready to merge into main as an opt-in mode. |
| 10. Optional | Greeter in the Drift look, `wind fullscreen`, "recently closed" in the command bar, night light. | |

## 8. Risks

- **Light glass over bright app windows** can wash out. Mitigation: popups that float over windows use a denser glass tier
  (Classic does the same with `Glass.sheet`; its brightness measurement covers only the wallpaper, not windows), and
  the gallery step tests every tier over white windows.
- **A bad QML file crash-loops the shell.** Every step is checked against `logs/jellyface.log` after a restart; Drift is
  opt-in, so `jellyface ui classic` is always one command away.
- **Shortcut clashes** with COSMIC (§6). They are tracked and reverted like every other system change.
- **Scope.** 17 surfaces is a lot. The checkpoints exist so the look can be corrected at step 1, not at step 8.

## 9. Decisions

Decided (2026-10-20):

- **Command bar: Super+Space**, taking over COSMIC's keyboard-layout switch while Drift is on (put back by `ui classic`).
- **Default look: light pastel.** Dark and Auto are in Appearance.
- **Step 1 is a live QML gallery**, not Figma.
- Classic's pending hover-intent work was committed to `main` (412a0b9) and this branch was rebased onto it.

Still open:

1. The name: "Drift" is a placeholder.
2. What plain Super does in Drift (nothing, the command bar too, or JellyPanel as in Classic).
3. Window hints on Super+J (overriding COSMIC's focus-down) or Super+G.
4. The Tidepool Figma direction: shelved in favour of this?
