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

    property bool enabled: true
    property real backdrop: 0.3 // wallpaper brightness under the shell's edges, 0-1
    readonly property real target: 0.45 // how bright the backdrop may look through the base glass: a whitish frost that still keeps white text readable

    // G0 Smoke: the base glass (bar, border, drawers, dock, desktop cards), drawn over the compositor's blur.
    // Dark wallpaper -> whitish frost (grey up to 0.82 at 35%); bright wallpaper -> darker smoked glass, so the result
    // never looks brighter than `target`. The same whether or not a drawer is open, so opening one (the dashboard opens
    // on hover) never changes the glass.
    function base(): color {
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
    readonly property color sheet: Qt.rgba(smoke.r * 0.25, smoke.g * 0.25, smoke.b * 0.25, Math.max(0.58, Math.min(0.8, smoke.a + 0.15)))

    // G1-G4: white over the base glass. More white reads as denser frost.
    readonly property color well: Qt.rgba(0, 0, 0, 0.1) // recessed (below G0)
    readonly property color veil: Qt.rgba(1, 1, 1, 0.06)
    readonly property color mist: Qt.rgba(1, 1, 1, 0.11) // G1: cards
    readonly property color mistHigh: Qt.rgba(1, 1, 1, 0.15)
    readonly property color frost: Qt.rgba(1, 1, 1, 0.2) // G2: raised tiles, hover, tracks
    readonly property color frostHigh: Qt.rgba(1, 1, 1, 0.27) // selected containers
    readonly property color haze: Qt.rgba(1, 1, 1, 0.74) // G3: secondary text, icons
    readonly property color hazeHigh: Qt.rgba(1, 1, 1, 0.86)
    readonly property color ice: Qt.rgba(1, 1, 1, 0.96) // G4: primary text, active pills
    readonly property color ink: "#17181b" // text and icons on an ice pill
    readonly property color rim: Qt.rgba(1, 1, 1, 0.22) // 1px edge of glass panes
    readonly property color sheen: Qt.rgba(1, 1, 1, 0.1) // top-lit gradient start inside a pane

    FileView {
        path: `${Paths.state}/glass.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const g = JSON.parse(text());
                root.enabled = g.enabled ?? true;
                root.backdrop = Math.max(0, Math.min(1, g.backdrop ?? 0.3));
            } catch (e) {
                console.warn(`Glass: bad glass.json: ${e}`);
            }
        }
        onLoadFailed: root.enabled = true
    }
}
