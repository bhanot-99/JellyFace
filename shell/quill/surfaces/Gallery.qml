pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.quill
import qs.quill.components

// The style gallery (`jellyface ipc quill open gallery`): every Quill token and component on one sheet, live, so the
// look can be judged (and tuned from Appearance) before anything is built from it.
Surface {
    id: root

    name: "gallery"
    anchors.fill: parent

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    component Section: Column {
        property alias kicker: k.text
        property alias title: t.text

        spacing: Theme.s3
        width: parent ? parent.width : 0

        Kicker {
            id: k
        }

        Label {
            id: t

            size: Theme.title
        }
    }

    component Swatch: Column {
        property color swatch
        property string label

        spacing: 6

        Rectangle {
            width: 46
            height: 46
            radius: 14
            color: parent.swatch
            border.width: 1
            border.color: Theme.rimSoft
        }

        Label {
            text: parent.label
            size: Theme.caption
            secondary: true
            width: 46
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Glass {
        id: sheet

        anchors.centerIn: parent
        width: parent.width - 64
        height: parent.height - 64
        color: Theme.sheet
        scale: 0.97 + 0.03 * root.progress

        // swallow clicks so only a click outside closes the Stage
        MouseArea {
            anchors.fill: parent
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: Theme.s6
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content

                width: parent.width
                spacing: Theme.s5

                // ── header ──
                Item {
                    width: parent.width
                    height: 92

                    Column {
                        spacing: 6

                        Kicker {
                            text: "JellyFace · Quill · style gallery"
                        }

                        Label {
                            text: "Calm by default. Glass by design."
                            size: Theme.display
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.8
                        }
                    }

                    Column {
                        anchors.right: parent.right
                        spacing: Theme.s3

                        Segmented {
                            width: 260
                            options: ["light", "dark", "auto"]
                            labels: ["Light", "Dark", "Auto"]
                            current: QuillConfig.theme
                            onPicked: o => QuillConfig.set("theme", o)
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: 10

                            Repeater {
                                model: Theme.accentNames

                                Rectangle {
                                    id: dot

                                    required property string modelData

                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: Theme.accents[modelData]
                                    border.width: QuillConfig.accent === modelData ? 3 : 0
                                    border.color: Theme.dark ? "#1C1B3A" : "#FFFFFF"

                                    Rectangle {
                                        visible: QuillConfig.accent === dot.modelData
                                        anchors.centerIn: parent
                                        width: parent.width + 6
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1.5
                                        border.color: dot.color
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: QuillConfig.set("accent", dot.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.s6

                Column {
                    width: (parent.width - Theme.s6) / 2
                    spacing: Theme.s5

                // ── colour ──
                Section {
                    kicker: "01 — Colour"
                    title: "Pastel glass, one accent"

                    Flow {
                        width: parent.width
                        spacing: Theme.s3

                        Swatch { swatch: Theme.ice; label: "ice" }
                        Swatch { swatch: Theme.rose; label: "rose" }
                        Swatch { swatch: Theme.peach; label: "peach" }
                        Swatch { swatch: Theme.lilac; label: "lilac" }
                        Swatch { swatch: Theme.sage; label: "sage" }
                        Item { width: Theme.s2; height: 1 }
                        Swatch { swatch: Theme.accent; label: "accent" }
                        Swatch { swatch: Theme.good; label: "good" }
                        Swatch { swatch: Theme.warn; label: "warning" }
                        Swatch { swatch: Theme.bad; label: "error" }
                        Item { width: Theme.s2; height: 1 }
                        Swatch { swatch: Theme.text; label: "text" }
                        Swatch { swatch: Theme.textSecondary; label: "secondary" }
                        Swatch { swatch: Theme.textMuted; label: "muted" }
                    }
                }

                // ── glass ──
                Section {
                    kicker: "02 — Material"
                    title: "As clear or as frosted as you like"

                    Row {
                        spacing: Theme.s5

                        Glass {
                            width: 250
                            height: 170
                            radius: Theme.radiusTile + 6

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.s4
                                spacing: Theme.s3

                                Label { text: "Pane"; font.weight: Font.DemiBold }
                                Label { text: "The body of every panel"; size: Theme.small; secondary: true }

                                Tile {
                                    width: parent.width
                                    height: 64

                                    Label {
                                        anchors.centerIn: parent
                                        text: "Tile"
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.parent.width - 250 - Theme.s5
                            spacing: Theme.s4

                            Row {
                                width: parent.width

                                Label { width: 110; text: "Transparency" }
                                Slider {
                                    width: parent.width - 110
                                    value: QuillConfig.transparency
                                    onMoved: v => QuillConfig.set("transparency", v)
                                }
                            }

                            Row {
                                width: parent.width

                                Label { width: 110; text: "Frost" }
                                Slider {
                                    width: parent.width - 110
                                    value: QuillConfig.frost
                                    onMoved: v => QuillConfig.set("frost", v)
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 52
                                radius: Theme.radiusRow
                                color: Theme.well

                                Label {
                                    anchors.centerIn: parent
                                    text: "Well — tracks, inputs, recessed areas"
                                    size: Theme.small
                                    secondary: true
                                }
                            }
                        }
                    }
                }

                // ── type ──
                Section {
                    kicker: "03 — Type"
                    title: "Inter, with a little mono"

                    Row {
                        spacing: Theme.s6

                        Column {
                            spacing: Theme.s2

                            Label { text: "Display 40"; size: Theme.display; font.weight: Font.DemiBold; font.letterSpacing: -0.8 }
                            Label { text: "Title 22"; size: Theme.title }
                            Label { text: "Heading 17"; size: Theme.heading; font.weight: Font.Medium }
                            Label { text: "Body 14 — the quick brown fox jumps over the lazy dog"; size: Theme.body }
                            Label { text: "Small 12 — secondary information"; size: Theme.small; secondary: true }
                            Kicker { text: "Caption — 02 · control center · wi-fi" }
                        }

                        Column {
                            spacing: Theme.s3

                            Label { text: "14:32"; size: 72; font.weight: Font.Light; font.letterSpacing: -2 }
                            Label { text: "Saturday, April 10"; size: Theme.heading; secondary: true }
                        }
                    }
                }

                }

                Column {
                    width: (parent.width - Theme.s6) / 2
                    spacing: Theme.s5

                // ── components ──
                Section {
                    kicker: "04 — Components"
                    title: "Everything you touch"

                    Flow {
                        width: parent.width
                        spacing: Theme.s5

                        Column {
                            width: 300
                            spacing: Theme.s4

                            Row {
                                spacing: Theme.s4

                                Toggle { id: t1; checked: true; onToggled: c => checked = c }
                                Toggle { checked: false; onToggled: c => checked = c }
                                Spinner { anchors.verticalCenter: parent.verticalCenter; size: 20 }
                            }

                            Slider { width: parent.width; icon: "volume_up"; value: 0.62; onMoved: v => value = v }
                            Slider { width: parent.width; icon: "light_mode"; value: 0.4; onMoved: v => value = v }

                            Segmented {
                                id: seg

                                width: parent.width
                                options: ["Saver", "Balanced", "Performance"]
                                current: "Balanced"
                                onPicked: o => current = o
                            }

                            Row {
                                spacing: Theme.s3

                                IconButton { icon: "bedtime"; onClicked: active = !active }
                                IconButton { icon: "light_mode"; active: true; onClicked: active = !active }
                                IconButton { icon: "desktop_windows" }
                                IconButton { icon: "settings" }
                            }

                            Row {
                                spacing: 6

                                Keycap { key: "Super" }
                                Label { text: "+"; muted: true; anchors.verticalCenter: parent.verticalCenter }
                                Keycap { key: "Space"; lit: true }
                                Item { width: Theme.s3; height: 1 }
                                Keycap { key: "Enter ↵"; large: true }
                            }
                        }

                        Glass {
                            width: parent.width - 300 - Theme.s5
                            height: 300
                            radius: Theme.radiusTile + 6

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 2

                                SearchField {
                                    width: parent.width
                                    placeholder: "Type to search"
                                }

                                ListRow { width: parent.width; icon: "terminal"; title: "Terminal"; trailing: "App"; current: true }
                                ListRow { width: parent.width; icon: "folder"; title: "Files"; trailing: "App" }
                                ListRow { width: parent.width; icon: "wifi"; title: "Home-5G"; checked: true; trailing: "Connected" }
                                ListRow { width: parent.width; icon: "wifi"; title: "Studio"; busy: true; trailing: "Connecting…" }
                                ListRow { width: parent.width; icon: "headphones"; title: "Sails Buds"; subtitle: "Battery 80%"; trailing: "Connected" }
                            }
                        }

                        Row {
                            spacing: Theme.s3

                            Pill {
                                anchors.verticalCenter: parent.verticalCenter
                                Label { text: "14:32"; size: Theme.small; font.weight: Font.Medium }
                                Label { text: "Sat, April 10"; size: Theme.small; secondary: true }
                                Icon { name: "wifi"; size: 14 }
                                Icon { name: "battery_5_bar"; size: 14 }
                            }

                            Pill {
                                anchors.verticalCenter: parent.verticalCenter
                                active: true

                                Icon { name: "do_not_disturb_on"; size: 14; color: Theme.accent }
                                Label { text: "Focus · 24:58"; size: Theme.small; font.weight: Font.Medium }
                            }

                            Tile {
                                width: 220
                                height: 72
                                onClicked: selected = !selected

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.s4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.s3

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Theme.accent

                                        Icon {
                                            anchors.centerIn: parent
                                            name: "wifi"
                                            size: 18
                                            filled: true
                                            color: "#FFFFFF"
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter

                                        Label { text: "Wi-Fi"; font.weight: Font.Medium }
                                        Label { text: "Home-5G"; size: Theme.small; secondary: true }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── motion ──
                Section {
                    kicker: "05 — Motion"
                    title: "One curve. Everywhere."

                    Row {
                        spacing: Theme.s5

                        // the curve itself, drawn, with a dot riding it
                        Rectangle {
                            id: graph

                            property real p

                            width: 240
                            height: 160
                            radius: Theme.radiusTile
                            color: Theme.tile
                            border.width: 1
                            border.color: Theme.rimSoft

                            SequentialAnimation on p {
                                running: root.visible
                                loops: Animation.Infinite

                                Anim { from: 0; to: 1; duration: 1100 }
                                PauseAnimation { duration: 700 }
                                PropertyAction { value: 0 }
                                PauseAnimation { duration: 300 }
                            }

                            Canvas {
                                id: curve

                                anchors.fill: parent
                                anchors.margins: 20
                                onPaint: {
                                    const c = getContext("2d");
                                    c.reset();
                                    c.strokeStyle = Theme.accent;
                                    c.lineWidth = 2.5;
                                    c.lineCap = "round";
                                    c.beginPath();
                                    const b = Theme.curve, w = width, h = height;
                                    c.moveTo(0, h);
                                    c.bezierCurveTo(b[0] * w, h - b[1] * h, b[2] * w, h - b[3] * h, w, 0);
                                    c.stroke();
                                }
                                Connections {
                                    function onAccentChanged(): void {
                                        curve.requestPaint();
                                    }

                                    target: Theme
                                }
                            }

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: "#FFFFFF"
                                border.width: 2
                                border.color: Theme.accent
                                x: 20 + graph.p * (graph.width - 40) - 7
                                // position along the drawn curve: the dot's height is the eased value at time p
                                y: 20 + (1 - ease.progress) * (graph.height - 40) - 7

                                QtObject {
                                    id: ease

                                    readonly property real progress: {
                                        // solve the bezier for x = p (a few Newton steps), return y
                                        const b = Theme.curve, x = graph.p;
                                        const bx = t => 3 * (1 - t) * (1 - t) * t * b[0] + 3 * (1 - t) * t * t * b[2] + t * t * t;
                                        const by = t => 3 * (1 - t) * (1 - t) * t * b[1] + 3 * (1 - t) * t * t * b[3] + t * t * t;
                                        let t = x;
                                        for (let i = 0; i < 8; i++) {
                                            const d = (bx(t + 0.001) - bx(t)) / 0.001;
                                            if (Math.abs(d) < 1e-6)
                                                break;
                                            t = Math.max(0, Math.min(1, t - (bx(t) - x) / d));
                                        }
                                        return by(t);
                                    }
                                }
                            }
                        }

                        // expand in place: the signature move
                        Item {
                            width: parent.parent.width - 240 - Theme.s5
                            height: 160

                            Tile {
                                id: grow

                                property bool open

                                x: open ? 0 : 0
                                width: open ? parent.width : 200
                                height: open ? 160 : 72
                                radius: open ? Theme.radiusTile + 6 : Theme.radiusTile
                                color: open ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : "#FFFFFF") : hovered ? Theme.tileHover : Theme.tile
                                onClicked: open = !open

                                Behavior on width { Anim { duration: Theme.slow } }
                                Behavior on height { Anim { duration: Theme.slow } }
                                Behavior on radius { Anim { duration: Theme.slow } }

                                Label {
                                    x: Theme.s4
                                    y: grow.open ? Theme.s4 : (72 - height) / 2
                                    text: grow.open ? "Wi-Fi" : "Click: expand in place"
                                    font.weight: Font.Medium

                                    Behavior on y { Anim { duration: Theme.slow } }
                                }

                                Column {
                                    x: Theme.s4
                                    y: 52
                                    width: parent.width - Theme.s6
                                    opacity: grow.open ? 1 : 0
                                    spacing: 0

                                    Behavior on opacity {
                                        Anim { duration: grow.open ? Theme.slow : Theme.fast }
                                    }

                                    ListRow { width: parent.width; rowHeight: 34; icon: "wifi"; title: "Home-5G"; checked: true; trailing: "Connected" }
                                    ListRow { width: parent.width; rowHeight: 34; icon: "wifi"; title: "Studio"; trailing: "Secured" }
                                }
                            }
                        }
                    }
                }

                }
                }

                Item {
                    width: 1
                    height: Theme.s3
                }
            }
        }
    }
}
