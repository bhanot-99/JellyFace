pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import M3Shapes
import Jellyface.Services
import qs.components.effects
import qs.services
import qs.utils
import qs.quill
import qs.quill.components

// The picture of Quill's lock screen, shared by the real lock (QuillLockSurface) and its preview (LockPreview).
// Quill's lock screen: Classic's lock screen layout in Quill's glass. Only the picture is Quill's: the session lock, its
// safety net and the password check are Classic's (modules/lock: Lock.qml creates this surface and LockBridge hands it
// the lock and the PAM check).
//   left    the weather, the system (jellyfacefetch), your agenda
//   centre  a big clock, the date, your picture (~/.face), the password, what went wrong
//   right   CPU, memory and storage, the notifications that came in, battery and power profile
//   corner  what is playing, in its own section nested into the card's bottom-right corner
// Typing goes straight into the password; Enter checks it; a wrong one shakes it.
Item {
    id: root

    property var pam: LockBridge.pam
    readonly property var player: Players.active
    property real shown: 1
    // the next few events (scripts/agenda.py keeps them in agenda.json), dropping each as it ends
    property var events: []
    readonly property var agenda: events.filter(e => new Date(e.end) > Time.date).slice(0, 4)

    function shakePassword(): void {
        shake.restart();
    }

    FileView {
        path: `${Paths.state}/agenda.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.events = JSON.parse(text()).events ?? [];
            } catch (e) {
                root.events = [];
            }
        }
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
        opacity: root.shown

        // the wallpaper, softly blurred as on Classic's lock screen (a lock surface gets no compositor blur)
        Sails {
            anchors.fill: parent
            living: QuillConfig.living
            darken: Theme.dark
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 0.7
                blurMax: 48
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.dark ? Qt.rgba(0.05, 0.05, 0.12, 0.35) : Qt.rgba(0.2, 0.2, 0.35, 0.12)
        }

        // ── the card ──
        // The card, with its bottom-right corner cut out for the media section, as in a nested layout: the card's
        // edge turns round the section with a rounded corner above it and a soft inside curve where they meet.
        Item {
            id: card

            readonly property real pad: 18
            readonly property real side: (width - pad * 2 - centre.width - 2 * 26) / 2
            readonly property real r: 36 // outer corners
            readonly property real gap: 14 // between the card and the media section
            readonly property real notchW: side + pad // the media section: as wide as the right column
            readonly property real notchH: 250
            readonly property real cutX: width - notchW - gap
            readonly property real cutY: height - notchH - gap

            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1400)
            height: Math.min(parent.height - 120, 820)
            scale: 0.94 + 0.06 * root.shown

            Shape {
                id: cardShape

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                layer.enabled: true
                layer.samples: 4
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadow
                    shadowBlur: 1
                    shadowVerticalOffset: 14
                    blurMax: 48
                }

                ShapePath {
                    readonly property real r: card.r
                    readonly property real w: card.width
                    readonly property real h: card.height

                    // denser than the desktop's glass: nothing is blurred behind a lock screen
                    fillColor: Qt.alpha(Theme.sheet, Math.max(0.9, Theme.sheet.a))
                    strokeColor: Theme.rimSoft
                    strokeWidth: 1
                    startX: r
                    startY: 0

                    PathLine { x: card.width - card.r; y: 0 }
                    PathArc { x: card.width; y: card.r; radiusX: card.r; radiusY: card.r }
                    // down the right side, round the corner above the media section
                    PathLine { x: card.width; y: card.cutY - card.r }
                    PathArc { x: card.width - card.r; y: card.cutY; radiusX: card.r; radiusY: card.r }
                    // along its top, then the soft inside curve down its left side
                    PathLine { x: card.cutX + card.r; y: card.cutY }
                    PathArc { x: card.cutX; y: card.cutY + card.r; radiusX: card.r; radiusY: card.r; direction: PathArc.Counterclockwise }
                    PathLine { x: card.cutX; y: card.height - card.r }
                    PathArc { x: card.cutX - card.r; y: card.height; radiusX: card.r; radiusY: card.r }
                    PathLine { x: card.r; y: card.height }
                    PathArc { x: 0; y: card.height - card.r; radiusX: card.r; radiusY: card.r }
                    PathLine { x: 0; y: card.r }
                    PathArc { x: card.r; y: 0; radiusX: card.r; radiusY: card.r }
                }
            }

            // ── the media section, in the cut-out ──
            Glass {
                id: mediaCard

                readonly property var p: root.player
                readonly property bool hasLength: !!p && p.length > 0 && p.length < 2147483647

                x: card.width - card.notchW
                y: card.height - card.notchH
                width: card.notchW
                height: card.notchH
                radius: card.r
                color: Qt.alpha(Theme.sheet, Math.max(0.9, Theme.sheet.a))

                Timer {
                    running: !!mediaCard.p?.isPlaying
                    interval: 1000
                    repeat: true
                    onTriggered: mediaCard.p?.positionChanged()
                }

                Row {
                    x: 22
                    y: 20
                    spacing: 8

                    Icon {
                        name: mediaCard.p?.isPlaying ? "graphic_eq" : "music_note"
                        size: 18
                        color: Theme.accent
                    }

                    Kicker {
                        anchors.verticalCenter: parent.verticalCenter
                        text: mediaCard.p ? (mediaCard.p.isPlaying ? "Now playing" : "Paused") : LastMedia.known ? "Last played" : "Media"
                    }
                }

                Rectangle {
                    id: mCover

                    x: 22
                    y: 54
                    width: 112
                    height: 112
                    radius: 22
                    color: Theme.lilac
                    clip: true

                    Image {
                        id: mArt

                        anchors.fill: parent
                        source: mediaCard.p ? Players.getArtUrl(mediaCard.p) : LastMedia.art
                        sourceSize: Qt.size(224, 224)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Icon {
                        visible: mArt.status !== Image.Ready
                        anchors.centerIn: parent
                        name: "album"
                        size: 44
                        color: "#FFFFFF"
                    }
                }

                Column {
                    anchors.left: mCover.right
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    y: 58
                    spacing: 3

                    Label {
                        width: parent.width
                        text: mediaCard.p?.trackTitle || LastMedia.title || "Nothing playing"
                        size: Theme.heading
                        font.weight: Font.DemiBold
                    }

                    Label {
                        width: parent.width
                        text: mediaCard.p?.trackArtist || LastMedia.artist || (mediaCard.p ? Players.getIdentity(mediaCard.p) : LastMedia.identity)
                        secondary: true
                    }

                    Item {
                        width: 1
                        height: 10
                    }

                    Row {
                        spacing: 8

                        IconButton { size: 40; icon: "skip_previous"; enabled: !!mediaCard.p; onClicked: mediaCard.p.previous() }
                        IconButton { size: 48; icon: mediaCard.p?.isPlaying ? "pause" : "play_arrow"; active: !!mediaCard.p; enabled: !!mediaCard.p; onClicked: mediaCard.p.togglePlaying() }
                        IconButton { size: 40; icon: "skip_next"; enabled: !!mediaCard.p; onClicked: mediaCard.p.next() }
                    }
                }

                // the progress, as a thin line along the bottom
                Rectangle {
                    x: 22
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 26
                    width: parent.width - 44
                    height: 4
                    radius: 2
                    color: Theme.well

                    Rectangle {
                        width: mediaCard.hasLength ? parent.width * Math.min(1, mediaCard.p.position / mediaCard.p.length) : 0
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                    }
                }
            }

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

                // what is on today and next (your calendars, from scripts/agenda.py)
                Tile {
                    width: parent.width
                    height: card.height - card.pad * 2 - 190 - 210 - 28
                    interactive: false
                    clip: true

                    Row {
                        x: 18
                        y: 16
                        spacing: 8

                        Icon {
                            name: "event"
                            size: 18
                            color: Theme.accent
                        }

                        Label {
                            text: "Agenda"
                            font.weight: Font.DemiBold
                        }
                    }

                    Label {
                        visible: root.agenda.length === 0
                        x: 18
                        y: 52
                        text: "Nothing coming up"
                        secondary: true
                    }

                    Column {
                        x: 14
                        y: 50
                        width: parent.width - 28
                        spacing: 4

                        Repeater {
                            model: root.agenda

                            Item {
                                id: ev

                                required property var modelData
                                readonly property date start: new Date(modelData.start)
                                readonly property bool today: Qt.formatDate(start, "yyyy-MM-dd") === Qt.formatDate(Time.date, "yyyy-MM-dd")

                                width: parent.width
                                height: 44

                                Rectangle {
                                    x: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 30
                                    radius: 1.5
                                    color: ev.today ? Theme.accent : Theme.textMuted
                                }

                                Column {
                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20

                                    Label {
                                        width: parent.width
                                        text: ev.modelData.title
                                        font.weight: Font.Medium
                                    }

                                    Label {
                                        width: parent.width
                                        text: (ev.today ? "Today" : Qt.formatDate(ev.start, "ddd, MMM d")) + (ev.modelData.allDay ? " · all day" : ` · ${Qt.formatTime(ev.start, "hh:mm")}`) + (ev.modelData.location ? ` · ${ev.modelData.location}` : "")
                                        size: Theme.small
                                        muted: true
                                    }
                                }
                            }
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
                        color: (root.pam?.buffer.length ?? 0) > 0 ? (goArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : Theme.well
                        scale: goArea.pressed && goArea.ready ? 0.92 : 1

                        Behavior on scale {
                            Anim { duration: Theme.fast }
                        }

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
                            id: goArea

                            readonly property bool ready: !!root.pam && !root.pam.passwd.active && root.pam.buffer.length > 0 && root.pam.state !== 2

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                            // the same checks Enter goes through (pam.handleKey): never while a check runs, never empty,
                            // never after too many tries
                            onClicked: if (ready) root.pam.passwd.start()
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
                    height: 160
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
                                    width: Math.min(96, (card.side - 80) / 3)
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

                // the notifications that came in: as tall as they need (two at most), one line when there are none
                Tile {
                    id: notifTile

                    readonly property var items: [...Notifs.notClosed].reverse().slice(0, 2)

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
                        text: Notifs.notClosed.length > 2 ? `${Notifs.notClosed.length} notifications · newest 2` : Notifs.notClosed.length > 0 ? `${Notifs.notClosed.length} notification${Notifs.notClosed.length === 1 ? "" : "s"}` : "No notifications"
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

                // battery and power
                Tile {
                    width: parent.width
                    height: 112
                    interactive: false

                    Row {
                        x: 18
                        y: 16
                        spacing: 8

                        Icon {
                            name: Power.charging || Power.full ? "battery_charging_full" : "battery_full"
                            size: 18
                            color: Power.present && Power.percent <= 0.2 && !Power.charging ? Theme.bad : Theme.good
                        }

                        Label {
                            text: Power.present ? "Battery" : "Power"
                            font.weight: Font.DemiBold
                        }
                    }

                    Pill {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        y: 12
                        visible: Power.profile !== ""
                        color: Theme.accentSoft

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Power.profile === "battery" ? "eco" : Power.profile === "performance" ? "bolt" : "balance"
                            size: 14
                            color: Theme.accent
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Power.profile === "battery" ? "Saver" : Power.profile === "performance" ? "Performance" : "Balanced"
                            size: Theme.small
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        visible: Power.present
                        x: 18
                        y: 52
                        width: parent.width - 36
                        spacing: 14

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${Math.round(Power.percent * 100)}%`
                            size: Theme.title
                            font.weight: Font.DemiBold
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 90
                            spacing: 6

                            Rectangle {
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Theme.well

                                Rectangle {
                                    width: parent.width * Power.percent
                                    height: parent.height
                                    radius: 3
                                    color: Power.percent <= 0.2 && !Power.charging ? Theme.bad : Theme.good
                                }
                            }

                            Label {
                                text: Power.timeText
                                size: Theme.small
                                muted: true
                            }
                        }
                    }

                    Label {
                        visible: !Power.present
                        x: 18
                        y: 56
                        text: "On mains power"
                        secondary: true
                    }
                }
            }
        }
    }
}
