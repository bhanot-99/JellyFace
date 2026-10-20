pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.quill

// Quill's design tokens: every colour, size, font and animation timing in Quill comes from here, so changing one value
// restyles the whole interface. Light is the default; dark and "auto" (dark from sunset to sunrise) come from
// QuillConfig.theme.
Singleton {
    id: root

    // ─── light / dark ───
    readonly property bool night: {
        const now = Time.date;
        const cc = Weather.cc;
        const rise = cc ? new Date(cc.sunrise) : null;
        const set = cc ? new Date(cc.sunset) : null;
        const mins = d => d.getHours() * 60 + d.getMinutes();
        const n = mins(now);
        if (rise && set && !isNaN(rise) && !isNaN(set))
            return n < mins(rise) || n >= mins(set);
        return n < 7 * 60 || n >= 19 * 60;
    }
    readonly property bool dark: QuillConfig.theme === "dark" || (QuillConfig.theme === "auto" && night)

    // COSMIC's own apps follow (Appearance → Theme), once the settings are read
    function syncCosmic(): void {
        if (QuillConfig.cosmicSync && QuillConfig.loaded)
            Quickshell.execDetached(["distrobox-host-exec", Quickshell.shellPath("../scripts/quill-cosmic.sh"), "mode", dark ? "dark" : "light"]);
    }

    // tiled windows with or without COSMIC's gaps (Appearance → Dock & bar); `jellyface ui classic` restores COSMIC's
    function syncGaps(): void {
        if (QuillConfig.loaded)
            Quickshell.execDetached(["distrobox-host-exec", Quickshell.shellPath("../scripts/quill-cosmic.sh"), "gaps", QuillConfig.windowGaps ? "restore" : "none"]);
    }

    onDarkChanged: syncCosmic()

    Connections {
        function onCosmicSyncChanged(): void {
            root.syncCosmic();
        }

        function onLoadedChanged(): void {
            root.syncCosmic();
            root.syncGaps();
        }

        function onWindowGapsChanged(): void {
            root.syncGaps();
        }

        target: QuillConfig
    }

    // ─── accent ───
    readonly property var accents: ({
            indigo: "#5B6CF0",
            violet: "#8B5CF6",
            pink: "#E0589A",
            orange: "#EE8445",
            green: "#2FAE7E",
            graphite: "#5F6675"
        })
    readonly property var accentNames: ["indigo", "violet", "pink", "orange", "green", "graphite"]
    readonly property color accent: accents[QuillConfig.accent] ?? accents.indigo
    readonly property color accentSoft: Qt.alpha(accent, dark ? 0.28 : 0.16)
    readonly property color accentText: "#FFFFFF"

    // ─── pastels (shared by the wallpaper, icons and the gallery) ───
    readonly property color ice: "#A9C8F5"
    readonly property color rose: "#F2B8CF"
    readonly property color peach: "#F7C9A3"
    readonly property color lilac: "#C4B5F2"
    readonly property color sage: "#B5D9C4"

    // ─── status (never derived from the accent) ───
    readonly property color good: "#2FB57A"
    readonly property color warn: "#E3A33B"
    readonly property color bad: "#E05656"

    // ─── text ───
    readonly property color text: dark ? "#F2F3FA" : "#1B1F3B"
    readonly property color textSecondary: dark ? "#B9BCD6" : "#5A6080"
    readonly property color textMuted: dark ? "#8186A6" : "#7C82A2"
    // the spaced-out mono section labels: a quiet tint of the accent
    readonly property color kicker: dark ? Qt.lighter(accent, 1.45) : Qt.darker(accent, 1.08)

    // ─── glass ───
    // t: 0 = solid, 1 = as clear as it gets (QuillConfig.transparency)
    readonly property real t: Math.max(0, Math.min(1, QuillConfig.transparency))
    readonly property real paneAlpha: (dark ? 0.9 : 0.95) - t * 0.42
    // pane: the body of a panel; sheet: a panel floating over app windows (a little denser so it reads over white
    // windows); tile: a card inside a pane; well: a slider track, input or recessed area
    readonly property color pane: dark ? Qt.rgba(0.13, 0.12, 0.27, paneAlpha) : Qt.rgba(0.975, 0.975, 1.0, paneAlpha)
    readonly property color sheet: dark ? Qt.rgba(0.12, 0.11, 0.25, Math.min(0.96, paneAlpha + 0.14)) : Qt.rgba(0.975, 0.975, 1.0, Math.min(0.97, paneAlpha + 0.14))
    readonly property color tile: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color tileHover: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.8)
    readonly property color well: dark ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(0.36, 0.4, 0.6, 0.12)
    readonly property color rim: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.85)
    readonly property color rimSoft: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color divider: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.11, 0.12, 0.23, 0.07)
    readonly property color shadow: dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0.24, 0.27, 0.51, 0.2)
    readonly property color scrim: dark ? Qt.rgba(0.05, 0.05, 0.12, 0.35) : Qt.rgba(0.85, 0.87, 0.95, 0.25)
    readonly property bool blur: QuillConfig.frost > 0.05
    // a milky haze over the glass, stronger with more frost
    readonly property color haze: dark ? Qt.rgba(1, 1, 1, 0.05 * QuillConfig.frost) : Qt.rgba(1, 1, 1, 0.14 * QuillConfig.frost)

    // ─── shape and space ───
    readonly property int radiusPane: 28
    readonly property int radiusTile: 20
    readonly property int radiusRow: 14
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32

    // ─── type ───
    readonly property string font: "Inter"
    readonly property string mono: "JetBrains Mono"
    readonly property string icons: "Material Symbols Rounded"
    readonly property int display: 40
    readonly property int title: 22
    readonly property int heading: 17
    readonly property int body: 14
    readonly property int small: 12
    readonly property int caption: 10

    // ─── motion: one curve for everything (a soft ease-out with no overshoot) ───
    readonly property list<real> curve: [0.22, 1, 0.36, 1, 1, 1]
    readonly property list<real> curveIn: [0.4, 0, 1, 1, 1, 1] // for things leaving
    readonly property int fast: 120
    readonly property int normal: 220
    readonly property int slow: 380
}
