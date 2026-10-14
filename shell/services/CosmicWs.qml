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
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer

        interval: 2000
        onTriggered: proc.running = true
    }
}
