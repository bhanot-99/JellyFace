pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import qs.components.effects
import qs.services
import qs.utils
import qs.drift
import qs.drift.components

// Drift's side bar: Classic's left bar, in Drift's glass. Top to bottom:
//   logo (the command bar) · desks · the focused app · tray · clock (Today) · focus timer · status icons (each opens
//   its Control Center page next to the bar) · bell (the right panel) · power (the power menu)
// Scrolling on the top half changes the volume, on the bottom half the brightness, as in Classic.
// "Minimal" (Appearance → Dock & bar) keeps the logo, desks, clock and power. Fullscreen windows hide it.
Scope {
    id: root

    readonly property bool full: DriftConfig.bar === "full"
    readonly property int barWidth: 52
    readonly property int margin: 8
    // A maximized window, or one reaching the bar, on this desk: the bar stops floating and fills the strip it already
    // reserves (square corners, full height, solid glass), so it reads as part of the window's frame instead of a pill
    // with the wallpaper peeking round it. The reserved width never changes, so windows never move.
    readonly property bool attached: CosmicWindows.windows.some(w => w.workspace_active && !w.minimized && w.w > 0 && (w.maximized || w.x <= barWidth + margin + 12))
    readonly property var monitor: Brightness.getMonitorForScreen(Quickshell.screens[0])

    PanelWindow {
        id: win

        screen: Quickshell.screens[0]
        visible: !CosmicWindows.fullscreen
        WlrLayershell.namespace: "jellyface-drift-sidebar"
        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: root.barWidth + root.margin
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        implicitWidth: root.barWidth + root.margin * 2
        color: "transparent"
        mask: Region {
            item: bar
        }

        BackgroundEffect.blurRegion: Theme.blur ? blur : null

        Region {
            id: blur

            BlurRegion {
                pane: bar.body
            }
        }

        Glass {
            id: bar

            // 0 floating, 1 attached
            property real a: root.attached ? 1 : 0

            x: root.margin * (1 - a)
            y: root.margin * (1 - a)
            width: root.barWidth + root.margin * a
            height: parent.height - root.margin * 2 * (1 - a)
            radius: root.barWidth / 2 * (1 - a)
            color: root.attached ? Theme.sheet : Theme.pane
            shadow: a < 0.5
            shadowStrength: 0.7

            Behavior on a {
                Anim { duration: Theme.normal }
            }

            // the seam against the window, once attached
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.divider
                opacity: bar.a
            }

            WheelHandler {
                id: wheel

                onWheel: e => {
                    const up = e.angleDelta.y > 0;
                    if (wheel.point.position.y > bar.height / 2) {
                        root.monitor?.setBrightness(Math.max(0.01, Math.min(1, root.monitor.brightness + (up ? 0.05 : -0.05))));
                    } else {
                        up ? Audio.incrementVolume() : Audio.decrementVolume();
                    }
                }
            }

            // ── top ──
            Column {
                id: top

                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                spacing: 16

                // the logo: every app, window and setting (the command bar)
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 36
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: logoArea.containsMouse || DriftState.open === "command" ? Theme.accentSoft : "transparent"

                        Behavior on color {
                            ColorAnim { duration: Theme.fast }
                        }
                    }

                    ColouredIcon {
                        anchors.centerIn: parent
                        source: `file://${Quickshell.shellPath("../assets/jellyface-symbolic.svg")}`
                        implicitSize: 24
                        colour: Theme.accent
                    }

                    MouseArea {
                        id: logoArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DriftState.toggle("command")
                    }
                }

                // desks
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Repeater {
                        model: CosmicWs.list

                        Rectangle {
                            id: desk

                            required property var modelData
                            required property int index
                            readonly property bool current: modelData.active
                            readonly property bool busy: CosmicWindows.windows.some(w => w.ws === index && !w.minimized)

                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 8
                            height: current ? 24 : 8
                            radius: 4
                            color: current ? Theme.accent : deskArea.containsMouse ? Theme.textSecondary : busy ? Theme.textMuted : Qt.alpha(Theme.textMuted, 0.45)

                            Behavior on height {
                                Anim {}
                            }
                            Behavior on color {
                                ColorAnim {}
                            }

                            MouseArea {
                                id: deskArea

                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CosmicWs.activate(desk.index)
                            }
                        }
                    }
                }
            }

            // ── middle: the focused app, its name running down the bar ──
            Column {
                id: middle

                visible: root.full && !!CosmicWindows.active
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: top.bottom
                anchors.topMargin: 22
                spacing: 10

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: 22
                    source: DriftApps.iconForClass(CosmicWindows.active?.app_id ?? "")
                    asynchronous: true
                }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 18
                    height: Math.min(title.implicitWidth, Math.max(0, bottom.y - top.y - top.height - 90))

                    Text {
                        id: title

                        anchors.centerIn: parent
                        width: parent.height
                        rotation: 90
                        text: {
                            const w = CosmicWindows.active;
                            return w ? (DriftApps.nameForClass(w.app_id) || w.title) : "";
                        }
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.small
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── bottom ──
            Column {
                id: bottom

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                spacing: 12

                // tray
                Column {
                    visible: root.full && SystemTray.items.values.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Repeater {
                        model: SystemTray.items

                        Item {
                            id: tray

                            required property var modelData

                            width: 20
                            height: 20

                            IconImage {
                                anchors.fill: parent
                                source: Icons.getTrayIcon(tray.modelData.id, tray.modelData.icon)
                                asynchronous: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: e => {
                                    const it = tray.modelData;
                                    if (e.button === Qt.RightButton || it.onlyMenu) {
                                        if (it.hasMenu) {
                                            const p = tray.mapToItem(win.contentItem, tray.width + 14, 0);
                                            it.display(win, p.x, p.y);
                                        } else {
                                            it.secondaryActivate();
                                        }
                                    } else {
                                        it.activate();
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.full
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 22
                    height: 1
                    color: Theme.divider
                }

                // clock: Today
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: clock.implicitHeight + 10
                    radius: 14
                    color: clockArea.containsMouse || DriftState.open === "today" ? Theme.accentSoft : "transparent"

                    Behavior on color {
                        ColorAnim { duration: Theme.fast }
                    }

                    Column {
                        id: clock

                        anchors.centerIn: parent

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Time.format("hh")
                            font.family: Theme.font
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                            color: Theme.text
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Time.format("mm")
                            font.family: Theme.font
                            font.pixelSize: 17
                            font.weight: Font.Normal
                            font.features: ({ "tnum": 1 })
                            color: Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: clockArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DriftState.toggle("today")
                    }
                }

                // the Deep Focus timer
                Rectangle {
                    visible: DeepFocus.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.accentSoft

                    Text {
                        anchors.centerIn: parent
                        text: DeepFocus.remainingText.split(":")[0]
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openCc("focus")
                    }
                }

                // status icons: each opens its Control Center page
                Column {
                    visible: root.full
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    StatusIcon {
                        icon: Nmcli.activeEthernet ? "lan" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                        page: "wifi"
                    }

                    StatusIcon {
                        icon: !Bluetooth.defaultAdapter?.enabled ? "bluetooth_disabled" : Bluetooth.devices.values.some(d => d.connected) ? "bluetooth_connected" : "bluetooth"
                        page: "bluetooth"
                    }

                    StatusIcon {
                        icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                        page: "sound"
                    }

                    StatusIcon {
                        visible: Power.present
                        icon: Icons.getBatteryIcon(Power.percent, Power.charging || Power.full)
                        tint: UPower.onBattery && Power.percent <= 0.2 ? Theme.bad : Theme.text
                        page: "battery"
                    }
                }

                // the bell: the right panel (notifications and quick toggles)
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 36
                    height: 36

                    IconButton {
                        anchors.fill: parent
                        size: 36
                        icon: Notifs.dnd ? "notifications_off" : "notifications"
                        active: DriftState.open === "panel"
                        onClicked: DriftState.toggle("panel")
                    }

                    Rectangle {
                        visible: Notifs.notClosed.length > 0 && !Notifs.dnd
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.accent
                        border.width: 1.5
                        border.color: Theme.dark ? "#1C1B3A" : "#FFFFFF"
                    }
                }

                IconButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 36
                    icon: "power_settings_new"
                    active: DriftState.open === "session"
                    onClicked: DriftState.toggle("session")
                }
            }
        }
    }

    function openCc(page: string): void {
        if (DriftState.open === "cc" && DriftState.ccPage === page) {
            DriftState.close();
            return;
        }
        DriftState.show("cc");
        DriftState.ccPage = page;
    }

    component StatusIcon: Rectangle {
        id: si

        property string icon
        property string page
        property color tint: Theme.text

        anchors.horizontalCenter: parent?.horizontalCenter
        width: 36
        height: 32
        radius: 12
        color: siArea.containsMouse || (DriftState.open === "cc" && DriftState.ccPage === page) ? Theme.accentSoft : "transparent"

        Behavior on color {
            ColorAnim { duration: Theme.fast }
        }

        Icon {
            anchors.centerIn: parent
            name: si.icon
            size: 18
            color: si.tint
            rotation: si.page === "battery" ? 90 : 0
        }

        MouseArea {
            id: siArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openCc(si.page)
        }
    }
}
