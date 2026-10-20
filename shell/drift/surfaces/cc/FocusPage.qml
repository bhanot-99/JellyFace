pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.drift
import qs.drift.components

// Focus: Do Not Disturb, a Deep Focus session of 25, 50 or 90 minutes (notifications wait, the dock and bar step
// aside, a timer runs in the top bar), and keeping the screen awake.
ListPage {
    id: root

    readonly property var sessions: [25, 50, 90]

    count: 2 + sessions.length
    onActivate: i => {
        if (i === 0)
            Notifs.dnd = !Notifs.dnd;
        else if (i <= sessions.length)
            DeepFocus.active ? DeepFocus.stop() : DeepFocus.start(sessions[i - 1]);
        else
            IdleInhibitor.enabled = !IdleInhibitor.enabled;
    }

    function until(minutes: int): string {
        return Qt.formatTime(new Date(Date.now() + minutes * 60000), "hh:mm");
    }

    header: PageHeader {
        title: "Focus"
    }

    ListRow {
        objectName: "row0"
        width: parent.width
        icon: "do_not_disturb_on"
        title: "Do Not Disturb"
        subtitle: "Notifications stay quiet until you turn it off"
        rowHeight: 48
        current: root.current === 0

        Toggle {
            checked: Notifs.dnd
            onToggled: c => Notifs.dnd = c
        }
    }

    Repeater {
        model: root.sessions

        ListRow {
            required property int modelData
            required property int index

            objectName: `row${index + 1}`
            width: parent.width
            icon: "self_improvement"
            title: `Deep Focus · ${modelData} min`
            subtitle: DeepFocus.active ? `On — ${DeepFocus.remainingText} left` : `Until ${root.until(modelData)} · notifications wait for you`
            rowHeight: 48
            current: root.current === index + 1
            trailing: DeepFocus.active ? "Stop" : "Start"
            onClicked: DeepFocus.active ? DeepFocus.stop() : DeepFocus.start(modelData)
        }
    }

    ListRow {
        objectName: `row${root.sessions.length + 1}`
        width: parent.width
        icon: "coffee"
        title: "Keep awake"
        subtitle: "The screen stays on and never locks by itself"
        rowHeight: 48
        current: root.current === root.sessions.length + 1

        Toggle {
            checked: IdleInhibitor.enabled
            onToggled: c => IdleInhibitor.enabled = c
        }
    }
}
