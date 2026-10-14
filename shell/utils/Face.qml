pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The profile picture (~/.face). Loading it when it does not exist made the image cache log a warning every single time
// a dashboard / lock screen was created (hundreds per day); now it is only loaded once it really exists.
Singleton {
    id: root

    readonly property string file: `${Paths.home}/.face`
    property bool exists
    // path to hand to CachingImage: empty while there is no picture
    readonly property string path: exists ? file : ""

    // call after changing the picture
    function refresh(): void {
        check.running = true;
    }

    Process {
        id: check

        running: true
        command: ["test", "-e", root.file]
        onExited: code => root.exists = code === 0
    }
}
