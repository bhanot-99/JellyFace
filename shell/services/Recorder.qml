pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording on COSMIC is done by Kooha, which has no start/stop/pause interface for other programs,
// so the shell only opens it; recording state, timer and controls live in Kooha's own window.
Singleton {
    id: root

    property int refCount: 0

    function openKooha(): void {
        proc.exec(["distrobox-host-exec", Quickshell.shellPath("../scripts/record.sh"), "open"]);
    }

    Process {
        id: proc
    }
}
