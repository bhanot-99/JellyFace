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
    readonly property int unreadCount: {
        let count = 0;
        for (let i = 0; i < emails.length; i++) {
            if (emails[i] && emails[i].unread)
                count++;
        }
        return count;
    }

    function refresh(): void {
        Quickshell.execDetached(["python3", script, "refresh"]);
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

    // Refresh every 5 minutes
    Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.refresh();
    }
}
