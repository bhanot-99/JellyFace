pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Mail service for the dashboard widget: monitors ~/.local/state/jellyface/mail.json
// and provides primary emails list, unread count, and client launcher actions.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("../scripts/mail.py")
    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/jellyface/mail.json`

    property var emails: []
    property bool isSyncing: false
    readonly property int unreadCount: {
        let count = 0;
        for (let i = 0; i < emails.length; i++) {
            if (emails[i] && emails[i].unread)
                count++;
        }
        return count;
    }

    function refresh(): void {
        if (isSyncing)
            return;
        isSyncing = true;
        syncTimeout.restart();
        refreshProc.running = true;
    }

    Process {
        id: refreshProc

        command: ["python3", root.script, "refresh"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (line.startsWith("__JELLYFACE_MAIL_JSON__")) {
                        try {
                            const jsonStr = line.substring("__JELLYFACE_MAIL_JSON__".length);
                            const data = JSON.parse(jsonStr);
                            if (data && data.emails) {
                                root.emails = data.emails;
                                console.info(`MailService: Synced ${data.emails.length} emails live`);
                            }
                        } catch (e) {
                            console.warn("MailService: parse error on stdout JSON", e);
                        }
                    } else if (line.length > 0) {
                        console.info("MailService:", line);
                    }
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.warn("MailService error:", text.trim());
            }
        }

        onExited: (code, status) => {
            root.isSyncing = false;
            syncTimeout.stop();
            file.reload();
        }
    }

    Timer {
        id: syncTimeout

        interval: 15000
        repeat: false
        onTriggered: {
            if (root.isSyncing) {
                root.isSyncing = false;
                refreshProc.running = false;
                file.reload();
            }
        }
    }

    function markRead(id: string): void {
        Quickshell.execDetached(["python3", script, "mark-read", id]);
        // Update locally immediately for instant UI response
        const updated = [];
        for (let i = 0; i < emails.length; i++) {
            const m = Object.assign({}, emails[i]);
            if (m.id === id)
                m.unread = false;
            updated.push(m);
        }
        emails = updated;
    }

    function openClient(client: string): void {
        Quickshell.execDetached(["python3", script, "open-client", client || "thunderbird"]);
    }

    function openGmail(): void {
        openClient("gmail");
    }

    FileView {
        id: file

        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.emails = data.emails || [];
            } catch (e) {
                console.warn("MailService: bad mail.json", e);
            }
        }
    }

    // Auto-sync every 90 minutes (5400000 ms)
    Timer {
        interval: 5400000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "mail"

        function refresh(): void {
            root.refresh();
        }

        function getEmails(): string {
            return JSON.stringify(root.emails);
        }
    }

    Component.onCompleted: {
        file.reload();
        root.refresh();
    }
}
