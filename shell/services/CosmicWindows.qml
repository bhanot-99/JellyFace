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
                    root.fullscreen = d.fullscreen;
                    // Switching windows or workspaces passes through "nothing focused" for 20-110 ms before COSMIC
                    // focuses the next window; showing that gap made the bar's title flick to "Desktop" and back
                    // (and the dock's focus dots blink) on every switch. A real new focus applies at once.
                    if (d.active !== 0 || root.activeId === 0) {
                        focusGap.stop();
                        root.activeId = d.active;
                    } else if (!focusGap.running) {
                        focusGap.restart();
                    }
                } catch (e) {}
            }
        }
        onRunningChanged: if (running) root.startedAt = Date.now()
        // restart the helper if it dies; one that keeps failing at once (e.g. a COSMIC update dropped the protocol)
        // is retried less and less often (2 s doubling up to 1 min) instead of being respawned every 2 s forever
        onExited: {
            root.windows = [];
            focusGap.stop();
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
        id: focusGap

        interval: 250
        onTriggered: root.activeId = 0
    }

    Timer {
        id: restartTimer

        onTriggered: proc.running = true
    }
}
