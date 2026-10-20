pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.quill
import qs.quill.components

// Every notification, newest first: click one for its action, × dismisses it, "Clear all" empties the list.
ListPage {
    id: root

    readonly property var items: [...Notifs.notClosed].reverse()

    count: items.length
    maxListHeight: 440
    onActivate: i => open(items[i])

    function open(n: var): void {
        const a = n.actions?.find(a => a.identifier === "default") ?? (n.actions?.length === 1 ? n.actions[0] : null);
        a?.invoke();
        n.close();
    }

    header: PageHeader {
        title: "Notifications"

        Pill {
            visible: root.items.length > 0
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            color: hovered ? Theme.tileHover : Theme.tile
            onClicked: {
                for (const n of root.items)
                    n.close();
            }

            Label {
                text: "Clear all"
                size: Theme.small
                font.weight: Font.Medium
            }
        }

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: !Notifs.dnd
            onToggled: c => Notifs.dnd = !c
        }
    }

    Item {
        visible: root.items.length === 0
        width: parent.width
        height: 110

        Column {
            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "notifications_off"
                size: 28
                color: Theme.textMuted
            }

            Label {
                text: Notifs.dnd ? "Do Not Disturb is on" : "You're all caught up"
                secondary: true
            }
        }
    }

    Repeater {
        model: root.items

        NotificationCard {
            required property var modelData
            required property int index

            objectName: `row${index}`
            width: parent.width
            notif: modelData
            current: root.current === index
            onOpened: root.open(modelData)
        }
    }
}
