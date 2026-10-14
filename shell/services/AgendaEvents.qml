pragma Singleton

import Quickshell
import Quickshell.Io

// Local calendar events (saved by scripts/agenda.py in ~/.local/state/jellyface/events.json and shown by the Agenda
// card next to your Google Calendar). The "new event" form lives in modules/agenda/EventForm.qml.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("../scripts/agenda.py")

    property bool formOpen
    property string presetDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

    function openForm(date: var): void {
        presetDate = Qt.formatDate(date ?? new Date(), "yyyy-MM-dd");
        formOpen = true;
    }

    function add(title: string, day: string, start: string, end: string, location: string): void {
        Quickshell.execDetached(["python3", script, "add", title, day, start, end, location]);
    }

    function remove(id: string): void {
        // agenda.py refreshes the card by itself after removing (a second, parallel refresh could write the old list back)
        Quickshell.execDetached(["python3", script, "remove", id]);
    }

    IpcHandler {
        function add(): void {
            root.openForm(new Date());
        }

        function close(): void {
            root.formOpen = false;
        }

        target: "agenda"
    }
}
