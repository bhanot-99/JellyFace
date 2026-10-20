pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Which Drift surface is open. Only one at a time: opening one closes the other, Esc closes it.
//   cc          Control Center              command   command bar        hints   window hints
//   desks       desk (workspace) overview    clipboard clipboard history  today   calendar, weather, media
//   appearance  Drift settings               keys      keyboard sheet     session power menu
// Shortcuts reach it through `jellyface ipc drift toggle <name>`, which writes to the socket below from the host (a few
// ms) instead of a `quickshell ipc` call through the container (about 230 ms).
Singleton {
    id: root

    property string open: ""
    // Control Center's expanded tile ("" = the grid), so a shortcut can open straight into a detail view
    property string ccPage: ""
    // Appearance's page
    property string appearancePage: "theme"
    // text the command bar opens with (`jellyface ipc drift search <text>`)
    property string commandText: ""

    readonly property var surfaces: ["cc", "command", "hints", "desks", "clipboard", "today", "appearance", "keys", "session", "gallery"]

    function toggle(name: string): void {
        if (open === name)
            close();
        else
            show(name);
    }

    function show(name: string): void {
        if (!surfaces.includes(name)) {
            console.warn(`drift: no surface called "${name}"`);
            return;
        }
        if (name !== "cc")
            ccPage = "";
        open = name;
    }

    function close(): void {
        open = "";
        ccPage = "";
    }

    function command(line: string): void {
        const [verb, arg] = line.trim().split(/\s+/);
        if (verb === "toggle")
            toggle(arg);
        else if (verb === "open")
            show(arg);
        else if (verb === "close")
            close();
    }

    // Classic's shortcuts keep working in Drift: Super (JellyPanel) opens the command bar, Super+V the clipboard.
    Connections {
        function onOpenChanged(): void {
            if (JellyPanel.open) {
                JellyPanel.open = false;
                root.toggle("command");
            }
        }

        target: JellyPanel
    }

    Connections {
        function onOpenChanged(): void {
            if (Clipboard.open) {
                Clipboard.open = false;
                root.toggle("clipboard");
            }
        }

        target: Clipboard
    }

    SocketServer {
        active: true
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/jellyface-drift.sock`
        handler: Socket {
            parser: SplitParser {
                onRead: line => root.command(line)
            }
        }
    }

    IpcHandler {
        function toggle(name: string): void {
            root.toggle(name);
        }

        function open(name: string): void {
            root.show(name);
        }

        function close(): void {
            root.close();
        }

        function current(): string {
            return root.open;
        }

        // open the command bar with this already typed
        function search(text: string): void {
            root.commandText = text;
            root.show("command");
        }

        // open Control Center on one of its pages: wifi bluetooth sound focus battery notifications
        function cc(page: string): void {
            root.show("cc");
            root.ccPage = page;
        }

        target: "drift"
    }

    // Classic's drawer names, so scripts, the COSMIC applet and tests/stability.sh work in Drift too
    function fromDrawer(drawer: string): string {
        return ({
                launcher: "command",
                dashboard: "today",
                sidebar: "cc",
                session: "session",
                utilities: "cc"
            })[drawer] ?? drawer;
    }

    IpcHandler {
        function toggle(drawer: string): void {
            root.toggle(root.fromDrawer(drawer));
        }

        function open(drawer: string): void {
            root.show(root.fromDrawer(drawer));
        }

        function close(drawer: string): void {
            if (root.open === root.fromDrawer(drawer))
                root.close();
        }

        function closeAll(): void {
            root.close();
        }

        target: "drawers"
    }
}
