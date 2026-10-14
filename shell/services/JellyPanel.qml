pragma Singleton

import Quickshell
import Quickshell.Io

// Whether JellyPanel (the full-screen app grid, modules/jellypanel) is open. Super toggles it through
// `jellyface ipc jellypanel toggle` (a COSMIC custom shortcut, see config/cosmic-shortcuts.ron), which uses the socket
// below when the shell is running.
Singleton {
    id: root

    property bool open

    // Fast path for the Super key: `jellyface ipc jellypanel ...` writes "toggle", "open" or "close" here straight
    // from the host (a few ms), instead of a `quickshell ipc` call through the container (about 230 ms).
    SocketServer {
        active: true
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/jellyface-jellypanel.sock`
        handler: Socket {
            parser: SplitParser {
                onRead: line => {
                    const cmd = line.trim();
                    if (cmd === "toggle")
                        root.open = !root.open;
                    else if (cmd === "open")
                        root.open = true;
                    else if (cmd === "close")
                        root.open = false;
                }
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

        target: "jellypanel"
    }
}
