pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.drift
import qs.drift.components

// The right panel (the bell on the side bar): Classic's notification sidebar and utilities, in Drift's glass.
// Every notification, newest first (click for its action, × to dismiss, Clear all), Do Not Disturb, and quick toggles:
// Wi-Fi, Bluetooth, Do Not Disturb, Keep awake, Dark mode, Deep Focus, Screenshot, Record.
// ↑/↓ walk the notifications, Enter opens one, Delete dismisses it.
Surface {
    id: root

    name: "panel"
    anchors.fill: parent
    rise: 0

    property int current: -1
    readonly property var items: [...Notifs.notClosed].reverse()

    function open(n: var): void {
        const a = n.actions?.find(a => a.identifier === "default") ?? (n.actions?.length === 1 ? n.actions[0] : null);
        a?.invoke();
        n.close();
    }

    onActiveChanged: current = -1

    Keys.onUpPressed: current = Math.max(0, current - 1)
    Keys.onDownPressed: current = Math.min(items.length - 1, current + 1)
    Keys.onReturnPressed: if (items[current]) open(items[current])
    Keys.onDeletePressed: if (items[current]) items[current].close()

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    component Quick: Column {
        id: q

        property string icon
        property string label
        property bool on
        signal clicked

        width: 78
        spacing: 6

        IconButton {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 48
            icon: q.icon
            active: q.on
            onClicked: q.clicked()
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: q.label
            size: Theme.caption + 1
            secondary: !q.on
        }
    }

    Glass {
        id: sheet

        x: parent.width - width - 10 + (1 - root.progress) * 80
        y: 10
        width: 400
        height: parent.height - 20
        color: Theme.sheet

        MouseArea {
            anchors.fill: parent
        }

        // ── header ──
        Item {
            id: header

            x: 20
            y: 18
            width: parent.width - 40
            height: 52

            Column {
                anchors.verticalCenter: parent.verticalCenter

                Kicker {
                    text: Time.format("dddd, MMMM d")
                }

                Label {
                    text: root.items.length > 0 ? `Notifications · ${root.items.length}` : "Notifications"
                    size: Theme.title
                    font.weight: Font.DemiBold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

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
            }
        }

        // ── the notifications ──
        Flickable {
            id: list

            anchors.top: header.bottom
            anchors.topMargin: 12
            anchors.bottom: divider.top
            anchors.bottomMargin: 12
            x: 12
            width: parent.width - 24
            contentHeight: column.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: column

                width: parent.width
                spacing: 6

                Repeater {
                    model: root.items

                    NotificationCard {
                        required property var modelData
                        required property int index

                        width: column.width
                        notif: modelData
                        current: root.current === index
                        onOpened: root.open(modelData)
                    }
                }
            }

            Column {
                visible: root.items.length === 0
                anchors.centerIn: parent
                spacing: 8

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Notifs.dnd ? "notifications_off" : "notifications_none"
                    size: 40
                    color: Theme.textMuted
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Notifs.dnd ? "Do Not Disturb is on" : "You're all caught up"
                    secondary: true
                }
            }
        }

        Rectangle {
            id: divider

            anchors.bottom: quick.top
            anchors.bottomMargin: 16
            x: 20
            width: parent.width - 40
            height: 1
            color: Theme.divider
        }

        // ── utilities ──
        Grid {
            id: quick

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 4
            rowSpacing: 14
            columnSpacing: 10

            Quick {
                icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
                label: "Wi-Fi"
                on: Nmcli.wifiEnabled
                onClicked: Nmcli.enableWifi(!Nmcli.wifiEnabled)
            }

            Quick {
                icon: Bluetooth.defaultAdapter?.enabled ? "bluetooth" : "bluetooth_disabled"
                label: "Bluetooth"
                on: !!Bluetooth.defaultAdapter?.enabled
                onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }

            Quick {
                icon: "do_not_disturb_on"
                label: "Do Not Disturb"
                on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Quick {
                icon: "coffee"
                label: "Keep awake"
                on: IdleInhibitor.enabled
                onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
            }

            Quick {
                icon: Theme.dark ? "dark_mode" : "light_mode"
                label: Theme.dark ? "Dark" : "Light"
                on: Theme.dark
                onClicked: DriftConfig.set("theme", Theme.dark ? "light" : "dark")
            }

            Quick {
                icon: "self_improvement"
                label: DeepFocus.active ? DeepFocus.remainingText : "Deep Focus"
                on: DeepFocus.active
                onClicked: DeepFocus.active ? DeepFocus.stop() : DeepFocus.start(0)
            }

            Quick {
                icon: "screenshot_region"
                label: "Screenshot"
                onClicked: {
                    DriftState.close();
                    Quickshell.execDetached(["distrobox-host-exec", "cosmic-screenshot"]);
                }
            }

            Quick {
                icon: "videocam"
                label: "Record"
                onClicked: {
                    DriftState.close();
                    Recorder.openKooha();
                }
            }
        }
    }
}
