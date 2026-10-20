pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Drift's own settings: ~/.config/jellyface/drift.json (defaults in config/drift.json; scripts/run.sh restores those if
// the file is broken). Every setter writes the file back at once, so the Appearance window and a hand edit agree.
Singleton {
    id: root

    property string theme: "light" // light | dark | auto (dark from sunset to sunrise)
    property string accent: "indigo"
    property string wallpaper: "system" // COSMIC's own; or one of Moods.names
    property bool living: true // wallpaper colours follow the time of day
    property real transparency: 0.5 // 0 = solid glass, 1 = as clear as it gets
    property real frost: 0.7 // 0 = no blur behind the glass, 1 = full frost
    property string dock: "autohide" // autohide (away while a window is on the desk) | always | off
    property string bar: "full" // the side bar: full | minimal
    property int focusMinutes: 25
    property bool cosmicSync: false // COSMIC's own apps follow light/dark (scripts/drift-cosmic.sh)
    property bool windowGaps: true // COSMIC's gaps around tiled windows (off: they fill the screen like a maximized one)

    property bool loaded
    readonly property var keys: ["theme", "accent", "wallpaper", "living", "transparency", "frost", "dock", "bar", "focusMinutes", "cosmicSync", "windowGaps"]

    function set(key: string, value: var): void {
        if (root[key] === value)
            return;
        root[key] = value;
        saveTimer.restart();
    }

    function load(text: string): void {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            console.warn("drift: drift.json is not valid JSON, using defaults");
            return;
        }
        for (const k of keys)
            if (data[k] !== undefined && typeof data[k] === typeof root[k])
                root[k] = data[k];
        loaded = true;
    }

    function save(): void {
        const out = {};
        for (const k of keys)
            out[k] = root[k];
        file.setText(JSON.stringify(out, null, 2) + "\n");
    }

    // a slider dragged across its range writes once at the end, not 60 times a second
    Timer {
        id: saveTimer

        interval: 400
        onTriggered: root.save()
    }

    FileView {
        id: file

        path: `${Paths.config}/drift.json`
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.load(text())
    }
}
