pragma ComponentBehavior: Bound

import QtQuick
import qs.drift
import qs.drift.components

// Battery: how much is left and for how long, the level over the last hours, and the power profile
// (Pop!_OS's system76-power: Battery saver / Balanced / Performance).
Item {
    id: root

    implicitHeight: col.implicitHeight

    function move(d: int): void {
        const order = ["battery", "balanced", "performance"];
        const i = Math.max(0, order.indexOf(Power.profile));
        Power.setProfile(order[Math.max(0, Math.min(2, i + d))]);
    }

    function enter(): void {
    }

    Column {
        id: col

        width: parent.width
        spacing: Theme.s3

        PageHeader {
            title: Power.present ? "Battery" : "Power"
        }

        Item {
            visible: Power.present
            width: parent.width
            height: 96

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.s2
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    text: `${Math.round(Power.percent * 100)}%`
                    size: 48
                    font.weight: Font.DemiBold
                    font.letterSpacing: -1.5
                }

                Label {
                    text: Power.timeText
                    size: Theme.small
                    secondary: true
                }
            }

            // the level over the last hours (one bar per 5 minutes, newest on the right)
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.s2
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 4

                Repeater {
                    model: Power.history.length > 1 ? Power.history.slice(-16) : [Power.percent]

                    Rectangle {
                        required property real modelData

                        anchors.bottom: parent.bottom
                        width: 9
                        height: Math.max(4, modelData * 64)
                        radius: 3
                        color: modelData <= 0.2 ? Theme.bad : Theme.good
                        opacity: 0.55 + modelData * 0.45
                    }
                }
            }
        }

        Segmented {
            width: parent.width
            options: ["battery", "balanced", "performance"]
            labels: ["Saver", "Balanced", "Performance"]
            current: Power.profile
            onPicked: o => Power.setProfile(o)
        }

        Label {
            width: parent.width
            leftPadding: Theme.s2
            text: Power.profile === "battery" ? "Longest battery life: a dimmer screen and a gentler CPU." : Power.profile === "performance" ? "Full speed: more heat, less battery." : "A balance of speed and battery life."
            size: Theme.small
            muted: true
            wrapMode: Text.WordWrap
        }
    }
}
