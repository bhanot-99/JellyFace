pragma Singleton

import Quickshell
import Quickshell.Io

// Whether the Mission Control / Window Switcher Overview is open.
// Super+W toggles it through `jellyface ipc overview toggle`.
Singleton {
    id: root

    property bool open

    function toggle(): void {
        root.open = !root.open;
    }

    SocketServer {
        active: true
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/jellyface-overview.sock`
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

        target: "overview"
    }
}
