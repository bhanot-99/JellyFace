pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// COSMIC windows (focused window, fullscreen state) via the cosmic-toplevel-info helper (helpers/cosmic-windows).
// Quickshell's own toplevel support needs wlr-foreign-toplevel-management, which COSMIC does not offer.
Singleton {
    id: root

    property var windows: []
    property int activeId: 0
    property bool fullscreen: false
    readonly property var active: windows.find(w => w.id === activeId) ?? null

    function activate(id: int): void {
        proc.write(`activate ${id}\n`);
    }

    Process {
        id: proc

        running: true
        stdinEnabled: true
        command: [Quickshell.shellPath("../helpers/cosmic-windows/wind")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const d = JSON.parse(data);
                    root.windows = d.windows;
                    root.activeId = d.active;
                    root.fullscreen = d.fullscreen;
                } catch (e) {}
            }
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer

        interval: 2000
        onTriggered: proc.running = true
    }
}
