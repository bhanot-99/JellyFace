pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Jellyface.Config

// Clipboard history. `wl-paste --watch` runs scripts/clipboard-store.py after every copy; the store (a JSON file)
// is read back here. COSMIC supports the data-control protocol that wl-paste --watch needs.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("../scripts/clipboard-store.py")
    readonly property string dir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/jellyface/clipboard`

    property var entries: []
    property bool open

    function toggle(): void {
        open = !open;
    }

    function copy(entry: var): void {
        if (entry.kind === "image")
            Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "_", entry.file]);
        else
            Quickshell.execDetached(["wl-copy", "--", entry.text]);
    }

    function togglePin(entry: var): void {
        Quickshell.execDetached(["python3", script, "pin", entry.id]);
    }

    function remove(entry: var): void {
        Quickshell.execDetached(["python3", script, "delete", entry.id]);
    }

    function clear(): void {
        Quickshell.execDetached(["python3", script, "clear"]);
    }

    Process {
        id: watcher

        running: true
        command: ["wl-paste", "--watch", "python3", root.script, "add"]
        onExited: restart.start()
    }

    Timer {
        id: restart

        interval: 5000
        onTriggered: watcher.running = true
    }

    FileView {
        path: `${root.dir}/history.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.entries = JSON.parse(text());
            } catch (e) {
                root.entries = [];
            }
        }
    }

    IpcHandler {
        function toggle(): void {
            root.open = !root.open;
        }

        function open(): void {
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }

        target: "clipboard"
    }
}
