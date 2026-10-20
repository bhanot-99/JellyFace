pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Deep Focus (Super+Shift+F, the same `jellyface ipc focus toggle` as Classic's focus mode): Do Not Disturb and the
// screen kept awake (services/FocusMode), plus a timer of QuillConfig.focusMinutes on the side bar while the dock
// steps aside. When the time is up, focus ends with a notification.
Singleton {
    id: root

    readonly property bool active: FocusMode.enabled
    property real endsAt: 0
    property real now: Date.now()
    readonly property int remaining: active ? Math.max(0, Math.round((endsAt - now) / 1000)) : 0
    readonly property string remainingText: `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")}`

    function start(minutes: int): void {
        endsAt = Date.now() + (minutes > 0 ? minutes : QuillConfig.focusMinutes) * 60000;
        if (!FocusMode.enabled)
            FocusMode.toggle();
    }

    function stop(): void {
        if (FocusMode.enabled)
            FocusMode.toggle();
    }

    function extend(minutes: int): void {
        endsAt += minutes * 60000;
    }

    Connections {
        function onEnabledChanged(): void {
            if (FocusMode.enabled && root.endsAt <= Date.now())
                root.endsAt = Date.now() + QuillConfig.focusMinutes * 60000;
            root.now = Date.now();
        }

        target: FocusMode
    }

    Timer {
        running: root.active
        repeat: true
        interval: 1000
        onTriggered: {
            root.now = Date.now();
            if (root.remaining <= 0) {
                root.stop();
                Quickshell.execDetached(["notify-send", "-a", "JellyFace", "Focus session done", "Notifications are back on."]);
            }
        }
    }
}
