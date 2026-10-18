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

    // asks the window to close, like its own close button (the app may still ask about unsaved work)
    function close(id: int): void {
        proc.write(`close ${id}\n`);
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
        onRunningChanged: if (running) root.startedAt = Date.now()
        // restart the helper if it dies; one that keeps failing at once (e.g. a COSMIC update dropped the protocol)
        // is retried less and less often (2 s doubling up to 1 min) instead of being respawned every 2 s forever
        onExited: {
            root.windows = [];
            root.activeId = 0;
            root.fullscreen = false;
            root.fails = Date.now() - root.startedAt < 10000 ? root.fails + 1 : 0;
            restartTimer.interval = Math.min(60000, 2000 * Math.pow(2, root.fails));
            restartTimer.start();
        }
    }

    property real startedAt
    property int fails

    Timer {
        id: restartTimer

        onTriggered: proc.running = true
    }
}
