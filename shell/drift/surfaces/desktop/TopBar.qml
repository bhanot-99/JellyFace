pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.services
import qs.utils
import qs.drift
import qs.drift.components

// Drift's top bar: no bar at all, just glass pills floating on the wallpaper.
//   left    desk dots (click to switch) and the focused app
//   centre  what is playing, while something plays (click: Today)
//   right   the focus timer while Deep Focus is on; time · date · network · battery (click the time: Today,
//           the rest: Control Center; scroll down on it also opens Control Center)
// "Minimal" (Appearance → Dock & bar) keeps only the time; Deep Focus keeps only the time and the timer. Fullscreen
// windows hide it.
Scope {
    id: root

    readonly property bool full: DriftConfig.bar === "full" && !DeepFocus.active
    readonly property bool hidden: CosmicWindows.fullscreen
    readonly property int barHeight: 40

    PanelWindow {
        id: win

        screen: Quickshell.screens[0]
        visible: !root.hidden
        WlrLayershell.namespace: "jellyface-drift-bar"
        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: root.full ? root.barHeight - 4 : 0
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: root.barHeight
        color: "transparent"
        mask: Region {
            Region { item: left.visible ? left : null }
            Region { item: media.visible ? media : null }
            Region { item: focusPill.visible ? focusPill : null }
            Region { item: status }
        }

        BackgroundEffect.blurRegion: Theme.blur ? blur : null

        Region {
            id: blur

            BlurRegion { pane: left }
            BlurRegion { pane: media }
            BlurRegion { pane: focusPill }
            BlurRegion { pane: status }
        }

        // ── left: desks and the focused app ──
        Pill {
            id: left

            visible: root.full
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: CosmicWs.list

                    Rectangle {
                        id: dot

                        required property var modelData
                        required property int index
                        readonly property bool current: modelData.active

                        anchors.verticalCenter: parent.verticalCenter
                        width: current ? 18 : 6
                        height: 6
                        radius: 3
                        color: current ? Theme.accent : dotArea.containsMouse ? Theme.textSecondary : Theme.textMuted

                        Behavior on width {
                            Anim {}
                        }
                        Behavior on color {
                            ColorAnim {}
                        }

                        MouseArea {
                            id: dotArea

                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: CosmicWs.activate(dot.index)
                        }
                    }
                }
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.small
                font.weight: Font.Medium
                text: {
                    const w = CosmicWindows.active;
                    if (!w)
                        return "Desktop";
                    return DriftApps.nameForClass(w.app_id) || w.title || "Desktop";
                }
                width: Math.min(implicitWidth, 260)
            }
        }

        // ── centre: now playing ──
        Pill {
            id: media

            readonly property var player: Players.active

            visible: root.full && !!player && player.isPlaying
            interactive: true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            padding: 4
            spacing: 8
            onClicked: DriftState.toggle("today")

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: Theme.lilac
                clip: true

                Image {
                    anchors.fill: parent
                    source: media.player ? Players.getArtUrl(media.player) : ""
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.small
                text: media.player ? `${media.player.trackTitle || "Playing"}${media.player.trackArtist ? " — " + media.player.trackArtist : ""}` : ""
                width: Math.min(implicitWidth, 320)
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "pause"
                size: 16
                filled: true
                rightPadding: 6

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: media.player?.togglePlaying()
                }
            }
        }

        // ── right: focus timer, then the status pill ──
        Pill {
            id: focusPill

            visible: DeepFocus.active
            active: true
            interactive: true
            anchors.right: status.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            onClicked: DriftState.toggle("cc")

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "do_not_disturb_on"
                size: 15
                color: Theme.accent
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.small
                font.weight: Font.Medium
                text: `Focus · ${DeepFocus.remainingText}`
            }
        }

        Pill {
            id: status

            readonly property var battery: UPower.displayDevice
            readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(battery.state)

            interactive: true
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            active: DriftState.open === "cc" || DriftState.open === "today"
            onClicked: DriftState.toggle("cc")

            Label {
                id: clock

                anchors.verticalCenter: parent.verticalCenter
                size: Theme.small
                font.weight: Font.DemiBold
                text: Time.format("hh:mm")

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DriftState.toggle("today")
                }
            }

            Label {
                visible: root.full
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.small
                secondary: true
                text: Time.format("ddd, MMM d")
            }

            Icon {
                visible: root.full && Notifs.dnd && !DeepFocus.active
                anchors.verticalCenter: parent.verticalCenter
                name: "do_not_disturb_on"
                size: 15
            }

            Rectangle {
                visible: root.full && Notifs.notClosed.length > 0 && !Notifs.dnd
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: Theme.accent
            }

            Icon {
                visible: root.full && Audio.muted
                anchors.verticalCenter: parent.verticalCenter
                name: "no_sound"
                size: 15
            }

            Icon {
                visible: root.full && !!Bluetooth.defaultAdapter?.enabled && Bluetooth.devices.values.some(d => d.connected)
                anchors.verticalCenter: parent.verticalCenter
                name: "bluetooth_connected"
                size: 15
            }

            Icon {
                visible: root.full
                anchors.verticalCenter: parent.verticalCenter
                name: Nmcli.activeEthernet ? "lan" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                size: 15
            }

            Row {
                visible: status.battery.isLaptopBattery
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Icons.getBatteryIcon(status.battery.percentage, status.charging)
                    rotation: 90
                    size: 15
                    color: UPower.onBattery && status.battery.percentage <= 0.2 ? Theme.bad : Theme.text
                }

                Label {
                    visible: root.full
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.small
                    secondary: true
                    text: `${Math.round(status.battery.percentage * 100)}%`
                }
            }

            WheelHandler {
                onWheel: e => {
                    if (e.angleDelta.y < 0 && DriftState.open !== "cc")
                        DriftState.show("cc");
                }
            }
        }
    }
}
