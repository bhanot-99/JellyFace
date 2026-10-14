pragma Singleton

import Quickshell
import Quickshell.Io

// Whether JellyPanel (the full-screen app grid, modules/jellypanel) is open. Super toggles it through
// `jellyface ipc jellypanel toggle` (a COSMIC custom shortcut, see config/cosmic-shortcuts.ron).
Singleton {
    id: root

    property bool open

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

        target: "jellypanel"
    }
}
