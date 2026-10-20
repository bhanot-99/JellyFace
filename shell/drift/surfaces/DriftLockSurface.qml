pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import M3Shapes
import Jellyface.Services
import qs.components.effects
import qs.services
import qs.utils
import qs.drift
import qs.drift.components

// Drift's lock screen: Classic's lock screen layout in Drift's glass. Only the picture is Drift's: the session lock, its
// safety net and the password check are Classic's (modules/lock: Lock.qml creates this surface and LockBridge hands it
// the lock and the PAM check).
//   left    the weather, the system (jellyfacefetch), what is playing
//   centre  a big clock, the date, your picture (~/.face), the password, what went wrong
//   right   CPU, memory and storage, and the notifications that came in
// Typing goes straight into the password; Enter checks it; a wrong one shakes it.
WlSessionLockSurface {
    id: root

    readonly property var lock: LockBridge.lock
    readonly property var pam: LockBridge.pam
    readonly property var player: Players.active
    property real shown: 0
    property bool leaving

    color: "black"

    Component.onCompleted: shown = 1

    Behavior on shown {
        NumberAnimation {
            duration: root.leaving ? 420 : 650
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.leaving ? Theme.curveIn : Theme.curve
        }
    }

    // unlocking: fade the lock screen away, then let the session go
    Connections {
        function onUnlock(): void {
            root.leaving = true;
            root.shown = 0;
            release.start();
        }

        target: root.lock
    }

    Timer {
        id: release

        interval: 440
        onTriggered: {
            if (root.lock)
                root.lock.locked = false;
        }
    }

    Connections {
        function onFlashMsg(): void {
            shake.restart();
        }

        target: root.pam
    }

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    Item {
        id: content

        anchors.fill: parent
        focus: true
        opacity: root.shown

        Keys.onPressed: e => root.pam?.handleKey(e)

        Sails {
            anchors.fill: parent
            living: DriftConfig.living
            darken: Theme.dark
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.dark ? Qt.rgba(0.05, 0.05, 0.12, 0.35) : Qt.rgba(0.2, 0.2, 0.35, 0.12)
        }

        // ── the card ──
        Glass {
            id: card

            readonly property real pad: 18
            readonly property real side: (width - pad * 2 - centre.width - 2 * 26) / 2

            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1400)
            height: Math.min(parent.height - 120, 820)
            radius: 36
            color: Theme.sheet
            scale: 0.94 + 0.06 * root.shown

            // ── left ──
            Column {
                id: left

                x: card.pad
                y: card.pad
                width: card.side
                spacing: 14

                // weather
                Tile {
                    width: parent.width
                    height: 190
                    interactive: false

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.description
                            size: Theme.heading
                            secondary: true
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.temp
                                size: 52
                                font.weight: Font.Light
                                font.letterSpacing: -1.5
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Weather.icon
                                size: 48
                                color: Theme.accent
                            }
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `Feels like ${Weather.feelsLike}`
                            secondary: true
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.forecast.length > 0 ? `High ${Math.round(Weather.forecast[0].maxTempC)}° · Low ${Math.round(Weather.forecast[0].minTempC)}°` : Weather.city
                            size: Theme.small
                            muted: true
                        }
                    }
                }

                // the system, as jellyfacefetch
                Tile {
                    width: parent.width
                    height: 210
                    interactive: false

                    Row {
                        x: 18
                        y: 16
                        spacing: 10

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 8
                            color: Theme.accentSoft

                            Text {
                                anchors.centerIn: parent
                                text: ">"
                                font.family: Theme.mono
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Theme.accent
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "jellyfacefetch.sh"
                            font.family: Theme.mono
                            font.pixelSize: 14
                            color: Theme.text
                        }
                    }

                    Row {
                        x: 18
                        y: 56
                        spacing: 18

                        ColouredIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: `file://${Quickshell.shellPath("../assets/jellyface-symbolic.svg")}`
                            implicitSize: 76
                            colour: Theme.accent
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Repeater {
                                model: [`WM  : ${SysInfo.wm}`, `USER: ${SysInfo.user}`, `UP  : ${SysInfo.uptimeShort || SysInfo.uptime}`, `BATT: ${Power.present ? `${Power.charging || Power.full ? "(+) " : ""}${Math.round(Power.percent * 100)}%` : "AC"}`]

                                Text {
                                    required property string modelData

                                    text: modelData
                                    font.family: Theme.mono
                                    font.pixelSize: 13
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    width: card.side - 140
                                }
                            }
                        }
                    }

                    // the palette, as a fetch shows its colours
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        spacing: 10

                        Repeater {
                            model: [Theme.accent, Theme.ice, Theme.lilac, Theme.rose, Theme.peach, Theme.sage, Theme.textSecondary]

                            Rectangle {
                                required property color modelData

                                width: 18
                                height: 18
                                radius: 9
                                color: modelData
                            }
                        }
                    }
                }

                // what is playing (or was)
                Tile {
                    width: parent.width
                    height: card.height - card.pad * 2 - 190 - 210 - 28
                    interactive: false
                    clip: true

                    Image {
                        id: coverBg

                        anchors.fill: parent
                        source: root.player ? Players.getArtUrl(root.player) : LastMedia.art
                        sourceSize: Qt.size(400, 400)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 0.35 : 0
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 40
                        spacing: 4

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.player?.trackTitle || LastMedia.title || "Nothing playing"
                            size: Theme.heading
                            font.weight: Font.DemiBold
                        }

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.player?.trackArtist || LastMedia.artist || (root.player || LastMedia.known ? "Unknown artist" : "")
                            secondary: true
                        }

                        Item {
                            width: 1
                            height: 8
                        }

                        Row {
                            visible: !!root.player
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10

                            IconButton { size: 40; icon: "skip_previous"; onClicked: root.player?.previous() }
                            IconButton { size: 48; icon: root.player?.isPlaying ? "pause" : "play_arrow"; active: true; onClicked: root.player?.togglePlaying() }
                            IconButton { size: 40; icon: "skip_next"; onClicked: root.player?.next() }
                        }
                    }
                }
            }

            // ── centre ──
            Column {
                id: centre

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 380
                spacing: 18

                // the clock: hours big, minutes beside them, as on Classic's
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Text {
                        text: Time.format("hh")
                        font.family: Theme.font
                        font.pixelSize: 150
                        font.weight: Font.DemiBold
                        font.letterSpacing: -6
                        font.features: ({ "tnum": 1 })
                        color: Theme.text
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 22
                        text: Time.format("mm")
                        font.family: Theme.font
                        font.pixelSize: 84
                        font.weight: Font.Light
                        font.features: ({ "tnum": 1 })
                        color: Theme.accent
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(Time.date, "dddd • d MMM").toUpperCase()
                    size: Theme.heading
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                    secondary: true
                }

                // your picture in a soft shape
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220
                    height: 220

                    Item {
                        id: faceMask

                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        MaterialShape {
                            implicitSize: 220
                            shape: MaterialShape.Cookie9Sided
                            color: "white"
                        }
                    }

                    MaterialShape {
                        implicitSize: 220
                        shape: MaterialShape.Cookie9Sided
                        color: Theme.accentSoft
                    }

                    Icon {
                        visible: face.status !== Image.Ready
                        anchors.centerIn: parent
                        name: "person"
                        size: 96
                        color: Theme.accent
                    }

                    Image {
                        id: face

                        anchors.fill: parent
                        source: Face.path ? `file://${Face.path}` : ""
                        sourceSize: Qt.size(440, 440)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                        layer.enabled: true
                        layer.effect: Mask {
                            maskSource: faceMask
                        }
                    }
                }

                // the password
                Glass {
                    id: pill

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 320
                    height: 52
                    radius: 26
                    color: Theme.tile
                    shadowStrength: 0.5

                    transform: Translate {
                        id: shakeX
                    }

                    SequentialAnimation {
                        id: shake

                        NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 60 }
                        NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70 }
                        NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 70 }
                        NumberAnimation { target: shakeX; property: "x"; to: 4; duration: 60 }
                        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                    }

                    Icon {
                        id: lockIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.pam?.passwd.active ? "lock_open" : "lock"
                        size: 18
                        color: Theme.textSecondary
                    }

                    // a dot per typed character (the password itself is never drawn)
                    Row {
                        anchors.left: lockIcon.right
                        anchors.leftMargin: 14
                        anchors.right: go.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        clip: true

                        Repeater {
                            model: Math.min(22, root.pam?.buffer.length ?? 0)

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9
                                height: 9
                                radius: 4.5
                                color: Theme.text
                            }
                        }
                    }

                    Label {
                        visible: (root.pam?.buffer.length ?? 0) === 0
                        anchors.left: lockIcon.right
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pam?.passwd.active ? "Checking…" : "Enter your password"
                        muted: true
                    }

                    Rectangle {
                        id: go

                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        radius: 19
                        color: (root.pam?.buffer.length ?? 0) > 0 ? Theme.accent : Theme.well

                        Behavior on color {
                            ColorAnim { duration: Theme.fast }
                        }

                        Spinner {
                            visible: !!root.pam?.passwd.active
                            anchors.centerIn: parent
                            size: 18
                            color: "#FFFFFF"
                        }

                        Icon {
                            visible: !root.pam?.passwd.active
                            anchors.centerIn: parent
                            name: "arrow_forward"
                            size: 18
                            color: (root.pam?.buffer.length ?? 0) > 0 ? "#FFFFFF" : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pam?.passwd.start()
                        }
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: {
                        const p = root.pam;
                        if (!p)
                            return "";
                        if (p.lockMessage)
                            return p.lockMessage;
                        if (p.state === 3)
                            return "Wrong password — try again";
                        if (p.state === 2)
                            return "Too many tries — wait a moment";
                        if (p.state === 1)
                            return "Couldn't check the password";
                        if (p.fprint.available && p.fprint.enabled)
                            return "Type your password or touch the fingerprint reader";
                        return `Welcome back, ${SysInfo.user}`;
                    }
                    size: Theme.small
                    font.weight: Font.Medium
                    color: root.pam && root.pam.state !== 0 ? Theme.bad : Theme.textSecondary
                }
            }

            // ── right ──
            Column {
                id: right

                x: card.width - card.pad - card.side
                y: card.pad
                width: card.side
                spacing: 14

                // resources, as rings
                Tile {
                    width: parent.width
                    height: 190
                    interactive: false

                    Row {
                        anchors.centerIn: parent
                        spacing: 18

                        Repeater {
                            model: [["memory", "CPU", Cpu.percentage, Cpu.temperature], ["memory_alt", "Memory", Memory.percentage, 0], ["hard_drive", "Storage", Storage.percentage, 0]]

                            Column {
                                id: gauge

                                required property var modelData

                                spacing: 6

                                Ring {
                                    width: Math.min(110, (card.side - 80) / 3)
                                    height: width
                                    thickness: 8
                                    value: gauge.modelData[2]
                                    color: gauge.modelData[2] > 0.85 ? Theme.bad : Theme.accent

                                    Column {
                                        anchors.centerIn: parent

                                        Icon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: gauge.modelData[0]
                                            size: 16
                                            color: Theme.textSecondary
                                        }

                                        Label {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: `${Math.round(gauge.modelData[2] * 100)}%`
                                            size: Theme.heading
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: gauge.modelData[3] > 0 ? `${gauge.modelData[1]} · ${Math.round(gauge.modelData[3])}°C` : gauge.modelData[1]
                                    size: Theme.small
                                    secondary: true
                                }
                            }
                        }
                    }
                }

                // the notifications that came in: as tall as they need (three at most), one line when there are none
                Tile {
                    id: notifTile

                    readonly property var items: [...Notifs.notClosed].reverse().slice(0, 3)

                    width: parent.width
                    height: items.length > 0 ? notifList.y + notifList.implicitHeight + 14 : 50
                    interactive: false
                    clip: true

                    Behavior on height {
                        Anim {}
                    }

                    Text {
                        x: 18
                        y: 16
                        text: Notifs.notClosed.length > 3 ? `${Notifs.notClosed.length} notifications · newest 3` : Notifs.notClosed.length > 0 ? `${Notifs.notClosed.length} notification${Notifs.notClosed.length === 1 ? "" : "s"}` : "No notifications"
                        font.family: Theme.mono
                        font.pixelSize: 13
                        color: Theme.textSecondary
                    }

                    Column {
                        id: notifList

                        x: 12
                        y: 46
                        width: parent.width - 24
                        spacing: 6

                        Repeater {
                            model: notifTile.items

                            NotificationCard {
                                required property var modelData

                                width: parent.width
                                notif: modelData
                                enabled: false // read-only while locked
                            }
                        }
                    }
                }
            }
        }
    }
}
