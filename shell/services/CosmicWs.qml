pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// COSMIC workspaces via the ext-workspace-v1 helper (helpers/cosmic-ws)
Singleton {
    id: root

    property var list: []
    readonly property int activeIndex: list.findIndex(w => w.active)

    function activate(i: int): void {
        proc.write(`activate ${i}\n`);
    }

    Process {
        id: proc

        running: true
        stdinEnabled: true
        command: [Quickshell.shellPath("../helpers/cosmic-ws/wsd")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.list = JSON.parse(data).ws.filter(w => !w.hidden);
                } catch (e) {}
            }
        }
        onRunningChanged: if (running) root.startedAt = Date.now()
        // restart the helper if it dies; one that keeps failing at once (e.g. a COSMIC update dropped the protocol)
        // is retried less and less often (2 s doubling up to 1 min) instead of being respawned every 2 s forever
        onExited: {
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
