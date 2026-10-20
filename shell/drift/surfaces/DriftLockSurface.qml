pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.services
import qs.drift
import qs.drift.components

// Drift's lock screen. Only the picture is Drift's: the session lock, its safety net and the password check are the
// same as Classic's (modules/lock: Lock.qml creates this surface and LockBridge hands it the lock and the PAM check).
// The glass sails, a big thin clock, the date, a glass password pill, what is playing and the battery. Typing goes
// straight into the password; Enter checks it; a wrong one shakes the pill.
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
            duration: root.leaving ? 420 : 600
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

        // a soft veil so the clock reads on any mood
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.28 : 0.06) }
                GradientStop { position: 0.6; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.3 : 0.08) }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.14 + (1 - root.shown) * -30
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Time.format("hh:mm")
                font.family: Theme.font
                font.pixelSize: Math.round(root.height * 0.17)
                font.weight: Font.ExtraLight
                font.letterSpacing: -4
                font.features: ({ "tnum": 1 })
                color: "#FFFFFF"
                style: Text.Raised
                styleColor: Qt.rgba(0.1, 0.1, 0.3, 0.12)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(Time.date, "dddd, MMMM d")
                font.family: Theme.font
                font.pixelSize: 22
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.92)
            }
        }

        // ── the password pill ──
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.62
            spacing: 12

            Glass {
                id: pill

                anchors.horizontalCenter: parent.horizontalCenter
                width: 340
                height: 56
                radius: 28
                color: Theme.sheet

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
                    anchors.leftMargin: 20
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
                        model: Math.min(24, root.pam?.buffer.length ?? 0)

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
                    text: root.pam?.passwd.active ? "Checking…" : "Enter password"
                    muted: true
                }

                Rectangle {
                    id: go

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
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

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
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
                    return "Type your password to unlock";
                }
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Medium
                color: root.pam && root.pam.state !== 0 ? "#FFE1E1" : Qt.rgba(1, 1, 1, 0.9)
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── bottom: what is playing, and the battery ──
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            spacing: 12

            Glass {
                visible: !!root.player
                width: Math.min(420, media.implicitWidth + 28)
                height: 56
                radius: 28
                color: Theme.sheet

                Row {
                    id: media

                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    spacing: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.lilac
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.player ? Players.getArtUrl(root.player) : ""
                            sourceSize: Qt.size(80, 80)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.player ? `${root.player.trackTitle || "Playing"}${root.player.trackArtist ? " — " + root.player.trackArtist : ""}` : ""
                        width: Math.min(implicitWidth, 260)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 34
                        icon: root.player?.isPlaying ? "pause" : "play_arrow"
                        onClicked: root.player?.togglePlaying()
                    }
                }
            }

            Glass {
                visible: Power.present
                width: bat.implicitWidth + 32
                height: 56
                radius: 28
                color: Theme.sheet

                Row {
                    id: bat

                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Power.charging || Power.full ? "battery_charging_full" : "battery_full"
                        size: 18
                        color: Power.percent <= 0.2 && !Power.charging ? Theme.bad : Theme.good
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round(Power.percent * 100)}%`
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
