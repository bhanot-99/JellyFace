pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Frosted-glass look: five neutral glass tiers instead of palette colours (Colours.qml swaps them in while this is on).
// The base glass adapts to how bright the wallpaper is along the screen edges (measured by scripts/theme.py into
// glass.json), so white text stays readable on any wallpaper: dark wallpaper -> light frosted grey, bright wallpaper ->
// darker smoked glass. Maths is in gamma-encoded luma, which is what the compositor blends in.
Singleton {
    id: root

    property bool enabled: false
    property real backdrop: 0.3 // wallpaper brightness under the shell's edges, 0-1
    readonly property real target: 0.45 // how bright the backdrop may look through the base glass: a whitish frost that still keeps white text readable

    // G0 Smoke: the base glass (bar, border, drawers, dock, desktop cards), drawn over the compositor's blur.
    // Dark wallpaper -> whitish frost (grey up to 0.82 at 35%); bright wallpaper -> darker smoked glass, so the result
    // never looks brighter than `target`. When glass is off, falls back to the palette's surface color.
    function base(): color {
        if (!enabled)
            return Colours.tPalette.m3surface;
        const w = backdrop;
        const a = Math.max(0.35, Math.min(0.8, 1 - target / Math.max(w, 0.01)));
        const g = Math.max(0, Math.min(0.82, (target - w * (1 - a)) / a));
        return Qt.rgba(g, g, g * 1.02, a);
    }

    // A pane standing on its own (desktop card, popup window): the base glass with colour c laid over it. Returns c
    // unchanged while glass is off, so callers can wrap their usual colour.
    function standalone(c: color): color {
        if (!enabled)
            return c;
        const b = base();
        const a = c.a + b.a * (1 - c.a);
        const mixc = (x, y) => (x * c.a + y * b.a * (1 - c.a)) / Math.max(a, 0.001);
        return Qt.rgba(mixc(c.r, b.r), mixc(c.g, b.g), mixc(c.b, b.b), a);
    }

    readonly property color smoke: base()
    // Popups and windows floating over apps (clipboard, event form, dock menus, settings, file dialog): the base glass
    // but smokier and a little denser, so they read over bright windows and white tiles on them do not turn milky
    readonly property color sheet: enabled
        ? Qt.rgba(smoke.r * 0.25, smoke.g * 0.25, smoke.b * 0.25, Math.max(0.58, Math.min(0.8, smoke.a + 0.15)))
        : Colours.palette.m3surfaceContainerHigh

    // ─── Luminous Frosted Glass & Dynamic Palette Design Tokens ───
    // 1. Surface Translucency Tiers (Resolves to Color Palette when glass is off)
    readonly property color glassCardBase:     enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Colours.tPalette.m3surfaceContainer
    readonly property color glassElevatedTile: enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.22) : Colours.palette.m3surfaceContainerHigh
    readonly property color glassPillHover:    enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.32) : Colours.palette.m3surfaceContainerHighest
    readonly property color glassRecessedWell: enabled ? Qt.rgba(0.0, 0.0, 0.0, 0.22) : Colours.palette.m3surfaceContainerLowest
    readonly property color glassActivePill:   enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.95) : Colours.palette.m3primary

    // 2. Continuous Clean Borders & Edge Rims
    readonly property color glassBorder:       enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.24) : Colours.palette.m3outlineVariant
    readonly property color glassBorderHover:  enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.48) : Colours.palette.m3outline
    readonly property color glassBorderMuted:  enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Colours.palette.m3outlineVariant
    readonly property color glassRimTop:       glassBorderHover
    readonly property color glassRimBottom:    glassBorder
    readonly property color glassInnerGlow:    glassBorderMuted

    // 3. Typography & Glyph Contrast (Preserves legibility in both glass and palette modes)
    readonly property color textPrimary:       enabled ? "#FFFFFF"                     : Colours.palette.m3onSurface
    readonly property color textSecondary:     enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.80) : Colours.palette.m3onSurfaceVariant
    readonly property color textMuted:         enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.55) : Colours.palette.m3outline
    readonly property color textDark:          enabled ? "#1A1D24"                     : Colours.palette.m3onPrimary

    // 4. Ambient Shadows
    readonly property color shadowAmbient:     enabled ? Qt.rgba(0.0, 0.0, 0.0, 0.28) : Qt.rgba(0.0, 0.0, 0.0, 0.35)
    readonly property color shadowDeep:        enabled ? Qt.rgba(0.0, 0.0, 0.0, 0.42) : Qt.rgba(0.0, 0.0, 0.0, 0.60)

    // G1-G4: Aliased to Design Tokens for unified design system
    readonly property color well: glassRecessedWell
    readonly property color veil: enabled ? Qt.rgba(1, 1, 1, 0.08) : Colours.palette.m3surfaceContainerLow
    readonly property color mist: glassCardBase
    readonly property color mistHigh: enabled ? Qt.rgba(1, 1, 1, 0.20) : Colours.palette.m3surfaceContainerHigh
    readonly property color frost: glassElevatedTile
    readonly property color frostHigh: glassPillHover
    readonly property color haze: textSecondary
    readonly property color hazeHigh: enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.88) : Colours.palette.m3onSurface
    readonly property color ice: glassActivePill
    readonly property color ink: textDark
    readonly property color rim: glassRimTop
    readonly property color sheen: glassInnerGlow

    FileView {
        path: `${Paths.state}/glass.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const g = JSON.parse(text());
                root.enabled = g.enabled ?? false;
                root.backdrop = Math.max(0, Math.min(1, g.backdrop ?? 0.3));
            } catch (e) {
                console.warn(`Glass: bad glass.json: ${e}`);
            }
        }
        onLoadFailed: root.enabled = false
    }
}
