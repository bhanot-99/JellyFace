// The login screen in Quill UI's look, used when you chose Quill (`jellyface ui quill`; stage.sh writes "ui" into
// greeter.json). Quill's lock screen (shell/quill/surfaces/LockScreen.qml) redrawn for the greeter: plain QtQuick and
// Canvas only, since the greeter renders in software with no JellyFace plugin, no Shapes and no blur effects.
//   left    the weather, the system (jellyfacefetch), power
//   centre  a big clock, the date, your picture, the password, what went wrong
//   right   CPU, memory and storage, notifications (none before login), battery
//   corner  the media section nested into the card's bottom-right corner (nothing plays before login)
// Quill's light/dark theme and accent come from greeter.json; the state and the login itself stay in shell.qml (g).
pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root

    required property var g

    focus: true

    // ─── Quill's tokens (shell/quill/Theme.qml) ───
    readonly property var accents: ({ indigo: "#5B6CF0", violet: "#8B5CF6", pink: "#E0589A", orange: "#EE8445", green: "#2FAE7E", graphite: "#5F6675" })
    readonly property string themeName: g.quill.theme || "light"
    readonly property bool dark: themeName === "dark" || (themeName === "auto" && (g.now.getHours() < 7 || g.now.getHours() >= 19))
    readonly property color accent: accents[g.quill.accent] || accents.indigo
    readonly property color accentSoft: Qt.alpha(accent, dark ? 0.28 : 0.16)
    readonly property color text: dark ? "#F2F3FA" : "#1B1F3B"
    readonly property color textSecondary: dark ? "#B9BCD6" : "#5A6080"
    readonly property color textMuted: dark ? "#8186A6" : "#7C82A2"
    readonly property color kicker: dark ? Qt.lighter(accent, 1.45) : Qt.darker(accent, 1.08)
    readonly property color sheet: dark ? Qt.rgba(0.12, 0.11, 0.25, 0.92) : Qt.rgba(0.975, 0.975, 1.0, 0.92)
    readonly property color tile: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color tileHover: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.8)
    readonly property color well: dark ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(0.36, 0.4, 0.6, 0.12)
    readonly property color rimSoft: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color shadow: dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0.24, 0.27, 0.51, 0.2)
    readonly property color good: "#2FB57A"
    readonly property color bad: "#E05656"
    readonly property color lilac: "#C4B5F2"
    readonly property var palette: [accent, "#A9C8F5", lilac, "#F2B8CF", "#F7C9A3", "#B5D9C4", textSecondary]
    readonly property string font: inter.status === FontLoader.Ready ? inter.name : "Inter"
    readonly property string mono: jbm.status === FontLoader.Ready ? jbm.name : "JetBrains Mono"
    readonly property string icons: "Material Symbols Rounded"

    FontLoader {
        id: inter
        source: "file://" + root.g.dataDir + "/Inter.ttf"
    }

    FontLoader {
        id: jbm
        source: "file://" + root.g.dataDir + "/JetBrainsMono.ttf"
    }

    // a wrong password shakes the field
    Connections {
        target: root.g
        function onErrorChanged() {
            if (root.g.error !== "")
                shake.restart();
        }
    }

    Keys.onPressed: event => {
        if (g.busy || g.started)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            g.submit();
        } else if (event.key === Qt.Key_Backspace) {
            g.buffer = (event.modifiers & Qt.ControlModifier) ? "" : g.buffer.slice(0, -1);
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            g.buffer += event.text;
        }
    }

    component QText: Text {
        property bool secondary
        property bool muted
        property int size: 14
        font.family: root.font
        font.pixelSize: size
        color: muted ? root.textMuted : secondary ? root.textSecondary : root.text
        elide: Text.ElideRight
    }

    component QIcon: Text {
        property string name
        property int size: 18
        font.family: root.icons
        font.pixelSize: size
        text: name
        color: root.text
    }

    component QTile: Rectangle {
        radius: 20
        color: root.tile
        border.width: 1
        border.color: root.rimSoft
    }

    // a ring gauge (Quill's Ring, on a Canvas)
    component QRing: Canvas {
        id: ring
        property real value: 0
        property color colour: root.accent
        property real thickness: 8
        onValueChanged: requestPaint()
        onColourChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const r = (Math.min(width, height) - thickness) / 2, cx = width / 2, cy = height / 2;
            ctx.lineWidth = thickness;
            ctx.lineCap = "round";
            ctx.strokeStyle = root.well;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();
            const v = Math.max(0, Math.min(1, value));
            if (v > 0) {
                ctx.strokeStyle = colour;
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + v * Math.PI * 2);
                ctx.stroke();
            }
        }
    }

    // the wallpaper, decoded tiny and scaled up smoothly: a cheap blur that works with software rendering
    Rectangle {
        anchors.fill: parent
        color: root.dark ? "#14132A" : "#DCDDF0"
    }

    Image {
        anchors.fill: parent
        source: "file://" + root.g.dataDir + "/bg.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(64, 36)
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        color: root.dark ? Qt.rgba(0.05, 0.05, 0.12, 0.35) : Qt.rgba(0.2, 0.2, 0.35, 0.12)
    }

    // ── the card: Quill's lock-screen size, scaled down to fit smaller screens ──
    Item {
        id: card

        readonly property real pad: 18
        readonly property real side: (width - pad * 2 - centre.width - 2 * 26) / 2
        readonly property real r: 36
        readonly property real gap: 14
        readonly property real notchW: side + pad
        readonly property real notchH: 250
        readonly property real cutX: width - notchW - gap
        readonly property real cutY: height - notchH - gap

        anchors.centerIn: parent
        width: 1400
        height: 820
        scale: Math.min(1, (root.width - 120) / width, (root.height - 120) / height)

        // the card's body with the bottom-right corner cut out for the media section, and its shadow
        Canvas {
            id: cardShape

            anchors.fill: parent
            anchors.margins: -24
            readonly property color fill: root.sheet
            readonly property color stroke: root.rimSoft
            readonly property color shade: root.shadow
            onFillChanged: requestPaint()
            onShadeChanged: requestPaint()

            function outline(ctx, o) {
                const r = card.r, w = card.width, h = card.height;
                ctx.beginPath();
                ctx.moveTo(o + r, o);
                ctx.lineTo(o + w - r, o);
                ctx.arcTo(o + w, o, o + w, o + r, r);
                ctx.lineTo(o + w, o + card.cutY - r);
                ctx.arcTo(o + w, o + card.cutY, o + w - r, o + card.cutY, r);
                ctx.lineTo(o + card.cutX + r, o + card.cutY);
                ctx.arcTo(o + card.cutX, o + card.cutY, o + card.cutX, o + card.cutY + r, r);
                ctx.lineTo(o + card.cutX, o + h - r);
                ctx.arcTo(o + card.cutX, o + h, o + card.cutX - r, o + h, r);
                ctx.lineTo(o + r, o + h);
                ctx.arcTo(o, o + h, o, o + h - r, r);
                ctx.lineTo(o, o + r);
                ctx.arcTo(o, o, o + r, o, r);
                ctx.closePath();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.save();
                ctx.shadowColor = shade;
                ctx.shadowBlur = 24;
                ctx.shadowOffsetY = 14;
                outline(ctx, 24);
                ctx.fillStyle = fill;
                ctx.fill();
                ctx.restore();
                ctx.lineWidth = 1;
                ctx.strokeStyle = stroke;
                ctx.stroke();
            }
        }

        // ── the media section, in the cut-out (no player runs before login) ──
        Rectangle {
            x: card.width - card.notchW
            y: card.height - card.notchH
            width: card.notchW
            height: card.notchH
            radius: card.r
            color: root.sheet
            border.width: 1
            border.color: root.rimSoft

            Row {
                x: 22
                y: 20
                spacing: 8

                QIcon {
                    name: "music_note"
                    color: root.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MEDIA"
                    font.family: root.mono
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 2.2
                    color: root.kicker
                    opacity: 0.85
                }
            }

            Rectangle {
                id: cover
                x: 22
                y: 54
                width: 112
                height: 112
                radius: 22
                color: root.lilac

                QIcon {
                    anchors.centerIn: parent
                    name: "album"
                    size: 44
                    color: "#FFFFFF"
                }
            }

            Column {
                anchors.left: cover.right
                anchors.leftMargin: 18
                anchors.right: parent.right
                anchors.rightMargin: 22
                y: 58
                spacing: 3

                QText {
                    width: parent.width
                    text: "Nothing playing"
                    size: 17
                    font.weight: Font.DemiBold
                }

                QText {
                    width: parent.width
                    text: "Your music shows here after you sign in"
                    secondary: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                Item {
                    width: 1
                    height: 10
                }

                Row {
                    spacing: 8
                    opacity: 0.5

                    Repeater {
                        model: [["skip_previous", 40], ["play_arrow", 48], ["skip_next", 40]]

                        Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData[1]
                            height: width
                            radius: width / 2
                            color: root.tile
                            border.width: 1
                            border.color: root.rimSoft

                            QIcon {
                                anchors.centerIn: parent
                                name: parent.modelData[0]
                                size: 20
                            }
                        }
                    }
                }
            }

            Rectangle {
                x: 22
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                width: parent.width - 44
                height: 4
                radius: 2
                color: root.well
            }
        }

        // ── left ──
        Column {
            x: card.pad
            y: card.pad
            width: card.side
            spacing: 14

            // weather
            QTile {
                width: parent.width
                height: 190

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    QText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.g.weatherText
                        size: 17
                        secondary: true
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        QText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.g.fmtTemp(root.g.wx.temp)
                            size: 52
                            font.weight: Font.Light
                            font.letterSpacing: -1.5
                        }

                        QIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.g.weatherIcon
                            size: 48
                            color: root.accent
                        }
                    }

                    QText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Feels like " + root.g.fmtTemp(root.g.wx.feels)
                        secondary: true
                    }

                    QText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.g.wx.hi !== undefined ? `High ${Math.round(root.g.wx.hi)}° · Low ${Math.round(root.g.wx.lo)}°` : ""
                        size: 12
                        muted: true
                    }
                }
            }

            // the system, as jellyfacefetch
            QTile {
                width: parent.width
                height: 210

                Row {
                    x: 18
                    y: 16
                    spacing: 10

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 8
                        color: root.accentSoft

                        Text {
                            anchors.centerIn: parent
                            text: ">"
                            font.family: root.mono
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: root.accent
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "jellyfacefetch.sh"
                        font.family: root.mono
                        font.pixelSize: 14
                        color: root.text
                    }
                }

                Row {
                    x: 18
                    y: 56
                    spacing: 18

                    // the JellyFace logo in the accent colour
                    Canvas {
                        id: logo
                        anchors.verticalCenter: parent.verticalCenter
                        width: 76
                        height: 76
                        readonly property string src: "file://" + root.g.dataDir + "/logo.svg"
                        readonly property color colour: root.accent
                        onColourChanged: requestPaint()
                        onImageLoaded: requestPaint()
                        Component.onCompleted: loadImage(src)
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            if (!isImageLoaded(src))
                                return;
                            ctx.drawImage(src, 0, 0, width, height);
                            ctx.globalCompositeOperation = "source-in";
                            ctx.fillStyle = colour;
                            ctx.fillRect(0, 0, width, height);
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: root.g.fetchLines

                            Text {
                                required property string modelData
                                text: modelData
                                font.family: root.mono
                                font.pixelSize: 13
                                color: root.textSecondary
                                elide: Text.ElideRight
                                width: card.side - 140
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    spacing: 10

                    Repeater {
                        model: root.palette

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

            // power: where the lock screen shows your agenda (your calendar is not shown before you sign in)
            QTile {
                width: parent.width
                height: card.height - card.pad * 2 - 190 - 210 - 28

                Row {
                    x: 18
                    y: 16
                    spacing: 8

                    QIcon {
                        name: "power_settings_new"
                        color: root.accent
                    }

                    QText {
                        text: "Power"
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    x: 12
                    y: 50
                    width: parent.width - 24
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "Sleep", icon: "bedtime", cmd: ["systemctl", "suspend"] },
                            { label: "Restart", icon: "restart_alt", cmd: ["systemctl", "reboot"] },
                            { label: "Shut down", icon: "power_settings_new", cmd: ["systemctl", "poweroff"] }
                        ]

                        Rectangle {
                            id: row
                            required property var modelData
                            width: parent.width
                            height: 40
                            radius: 14
                            color: rowArea.containsMouse ? root.tileHover : "transparent"

                            Row {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                QIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: row.modelData.icon
                                    color: root.textSecondary
                                }

                                QText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.label
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.g.testMode) {
                                        root.g.powerProc.command = row.modelData.cmd;
                                        root.g.powerProc.running = true;
                                    }
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

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: root.g.hh
                    font.family: root.font
                    font.pixelSize: 150
                    font.weight: Font.DemiBold
                    font.letterSpacing: -6
                    font.features: ({ "tnum": 1 })
                    color: root.text
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 22
                    text: root.g.mm
                    font.family: root.font
                    font.pixelSize: 84
                    font.weight: Font.Light
                    font.features: ({ "tnum": 1 })
                    color: root.accent
                }
            }

            QText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.g.dateText
                size: 17
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
                secondary: true
            }

            // your picture in Quill's nine-sided cookie (drawn on a Canvas: masks need a GPU)
            Canvas {
                id: avatar

                anchors.horizontalCenter: parent.horizontalCenter
                width: 220
                height: 220
                readonly property string photo: "file://" + root.g.dataDir + "/face.png"
                readonly property color fill: root.accentSoft
                onFillChanged: requestPaint()
                onImageLoaded: requestPaint()

                Image {
                    id: photoImg
                    visible: false
                    source: avatar.photo
                    sourceSize: Qt.size(440, 440)
                    onStatusChanged: if (status === Image.Ready) avatar.loadImage(source)
                }

                QIcon {
                    visible: photoImg.status !== Image.Ready
                    anchors.centerIn: parent
                    name: "person"
                    size: 96
                    color: root.accent
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2, R = width / 2;
                    ctx.beginPath();
                    for (let i = 0; i <= 360; i++) {
                        const a = i * Math.PI / 180;
                        const r = R * (0.93 + 0.07 * Math.cos(9 * a));
                        const x = cx + r * Math.cos(a - Math.PI / 2), y = cy + r * Math.sin(a - Math.PI / 2);
                        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                    }
                    ctx.closePath();
                    ctx.fillStyle = fill;
                    ctx.fill();
                    if (photoImg.status === Image.Ready && isImageLoaded(photoImg.source)) {
                        ctx.save();
                        ctx.clip();
                        const sc = Math.max(width / photoImg.implicitWidth, height / photoImg.implicitHeight);
                        const iw = photoImg.implicitWidth * sc, ih = photoImg.implicitHeight * sc;
                        ctx.drawImage(photoImg.source, (width - iw) / 2, (height - ih) / 2, iw, ih);
                        ctx.restore();
                    }
                }
            }

            // the password
            Rectangle {
                id: pill

                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 52
                radius: 26
                color: root.tile
                border.width: 1
                border.color: root.rimSoft

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

                QIcon {
                    id: lockIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.g.busy ? "lock_open" : "lock"
                    color: root.textSecondary
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
                        model: Math.min(22, root.g.buffer.length)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 9
                            radius: 4.5
                            color: root.text
                        }
                    }
                }

                QText {
                    visible: root.g.buffer.length === 0
                    anchors.left: lockIcon.right
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.g.busy || root.g.started ? "Signing in…" : "Enter your password"
                    muted: true
                }

                Rectangle {
                    id: go

                    readonly property bool ready: root.g.buffer.length > 0 && !root.g.busy && !root.g.started

                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    radius: 19
                    color: go.ready ? (goArea.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent) : root.well
                    scale: goArea.pressed && go.ready ? 0.92 : 1

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    QIcon {
                        anchors.centerIn: parent
                        name: root.g.busy ? "progress_activity" : "arrow_forward"
                        color: go.ready || root.g.busy ? "#FFFFFF" : root.textSecondary
                    }

                    MouseArea {
                        id: goArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: go.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (go.ready) root.g.submit()
                    }
                }
            }

            QText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.g.error !== "" ? root.g.error : `Welcome back, ${root.g.user}`
                size: 12
                font.weight: Font.Medium
                color: root.g.error !== "" ? root.bad : root.textSecondary
            }
        }

        // ── right ──
        Column {
            x: card.width - card.pad - card.side
            y: card.pad
            width: card.side
            spacing: 14

            // resources, as rings
            QTile {
                width: parent.width
                height: 160

                Row {
                    anchors.centerIn: parent
                    spacing: 18

                    Repeater {
                        model: [["memory", "CPU", root.g.cpu / 100, root.g.temp], ["memory_alt", "Memory", root.g.mem / 100, 0], ["hard_drive", "Storage", root.g.disk / 100, 0]]

                        Column {
                            id: gauge
                            required property var modelData
                            spacing: 6

                            QRing {
                                width: Math.min(96, (card.side - 80) / 3)
                                height: width
                                value: gauge.modelData[2]
                                colour: gauge.modelData[2] > 0.85 ? root.bad : root.accent

                                Column {
                                    anchors.centerIn: parent

                                    QIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: gauge.modelData[0]
                                        size: 16
                                        color: root.textSecondary
                                    }

                                    QText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: `${Math.round(gauge.modelData[2] * 100)}%`
                                        size: 17
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            QText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: gauge.modelData[3] > 0 ? `${gauge.modelData[1]} · ${Math.round(gauge.modelData[3])}°C` : gauge.modelData[1]
                                size: 12
                                secondary: true
                            }
                        }
                    }
                }
            }

            // notifications: none exist before login
            QTile {
                width: parent.width
                height: 50

                Text {
                    x: 18
                    y: 16
                    text: "No notifications"
                    font.family: root.mono
                    font.pixelSize: 13
                    color: root.textSecondary
                }
            }

            // battery
            QTile {
                id: batt
                width: parent.width
                height: 112

                readonly property bool present: root.g.battery >= 0
                readonly property bool low: present && root.g.battery <= 20 && !root.g.charging

                Row {
                    x: 18
                    y: 16
                    spacing: 8

                    QIcon {
                        name: root.g.charging ? "battery_charging_full" : "battery_full"
                        color: batt.low ? root.bad : root.good
                    }

                    QText {
                        text: batt.present ? "Battery" : "Power"
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    visible: batt.present
                    x: 18
                    y: 52
                    width: parent.width - 36
                    spacing: 14

                    QText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${root.g.battery}%`
                        size: 22
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
                            color: root.well

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, root.g.battery / 100))
                                height: parent.height
                                radius: 3
                                color: batt.low ? root.bad : root.good
                            }
                        }

                        QText {
                            text: root.g.charging ? "Charging" : "On battery"
                            size: 12
                            muted: true
                        }
                    }
                }

                QText {
                    visible: !batt.present
                    x: 18
                    y: 56
                    text: "On mains power"
                    secondary: true
                }
            }
        }
    }
}
