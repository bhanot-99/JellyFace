pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Wallpaper moods for the "glass sails" (components/Sails.qml): a sky gradient and five sail colours each, back to
// front. "system" draws nothing and leaves COSMIC's own wallpaper. With DriftConfig.living the sails are tinted by
// the time of day (dawn, noon, golden hour, dusk, night).
Singleton {
    id: root

    readonly property var names: ["mist", "aurora", "dusk", "night", "blush", "mono", "system"]
    readonly property var labels: ({
            mist: "Mist",
            aurora: "Aurora",
            dusk: "Dusk",
            night: "Night",
            blush: "Blush",
            mono: "Mono",
            system: "System"
        })
    readonly property var moods: ({
            mist: {
                dark: false,
                sky: ["#DDE4F8", "#EBDDF2", "#F5DCE6"],
                sails: ["#B9C9F2", "#C9B9EE", "#A9C4F0", "#F2C2D6", "#F6D2BC"]
            },
            aurora: {
                dark: true,
                sky: ["#0F2A40", "#1C2E5C", "#2A2668"],
                sails: ["#2F8F8A", "#3E6FC8", "#46B3A0", "#6E5ACF", "#3D9CC0"]
            },
            dusk: {
                dark: false,
                sky: ["#F4C7A9", "#E9B3C6", "#C7A6E2"],
                sails: ["#F2A98F", "#E89AB7", "#F6C19A", "#C9A0E6", "#F0B3A0"]
            },
            night: {
                dark: true,
                sky: ["#15142E", "#211E52", "#2C2869"],
                sails: ["#4A46B8", "#3A378F", "#6A60D8", "#2F2C7A", "#7F74E6"]
            },
            blush: {
                dark: false,
                sky: ["#F8DCE7", "#F1D8EE", "#E5D8F6"],
                sails: ["#F0B5CB", "#E9C1E2", "#F6C9D5", "#D9C2F0", "#F7D0C4"]
            },
            mono: {
                dark: false,
                sky: ["#ECEDF1", "#E2E4EA", "#D8DAE2"],
                sails: ["#C9CCD6", "#B8BCC8", "#D6D8E0", "#A9AEBC", "#DADCE3"]
            }
        })

    // COSMIC's own wallpaper (the "system" mood), from its background settings; empty for a slideshow folder
    property string systemWallpaper

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/cosmic/com.system76.CosmicBackground/v1/all`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/source:\s*Path\("([^"]+)"\)/);
            root.systemWallpaper = m && /\.(jpe?g|png|webp|bmp|avif|jxl)$/i.test(m[1]) ? `file://${m[1]}` : "";
        }
    }

    function mood(name: string): var {
        return moods[name] ?? moods.mist;
    }

    // The time-of-day tint laid over a light mood's sails: [r, g, b, alpha], eased between the keyframes below.
    readonly property var tint: {
        const d = Time.date;
        const h = d.getHours() + d.getMinutes() / 60;
        // hour, colour, strength
        const keys = [[0, [0.07, 0.06, 0.24], 0.5], [5, [0.07, 0.06, 0.24], 0.45], [6.5, [1, 0.72, 0.55], 0.2], [8.5, [1, 1, 1], 0], [16.5, [1, 1, 1], 0], [18.3, [1, 0.6, 0.32], 0.24], [19.6, [0.55, 0.38, 0.8], 0.28], [21, [0.07, 0.06, 0.24], 0.48], [24, [0.07, 0.06, 0.24], 0.5]];
        let i = 0;
        while (i < keys.length - 2 && h >= keys[i + 1][0])
            i++;
        const [h0, c0, a0] = keys[i], [h1, c1, a1] = keys[i + 1];
        const f = Math.max(0, Math.min(1, (h - h0) / (h1 - h0)));
        const mix = (x, y) => x + (y - x) * f;
        // a colourless (white, 0) keyframe only fades the strength, it does not wash the colour out
        const c = a0 === 0 ? c1 : a1 === 0 ? c0 : [mix(c0[0], c1[0]), mix(c0[1], c1[1]), mix(c0[2], c1[2])];
        return [c[0], c[1], c[2], mix(a0, a1)];
    }

    function partOfDay(): string {
        const h = Time.hours;
        return h < 5 ? "Night" : h < 8 ? "Dawn" : h < 16 ? "Day" : h < 19 ? "Golden hour" : h < 21 ? "Dusk" : "Night";
    }
}
