pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.drift
import qs.drift.components

// Appearance (Super+P, the command bar, or ⚙ in Control Center): make it yours. Every change applies at once.
//   Theme      light, dark or auto (dark from sunset to sunrise); COSMIC's own apps can follow
//   Accent     one colour used everywhere
//   Wallpaper  the glass sails in six moods (or COSMIC's own wallpaper); "living" follows the time of day
//   Glass      transparency and frost, with a live preview
//   Dock & bar always / auto-hide / off; full / minimal; the Deep Focus length
//   Keyboard   every shortcut     About   switch back to Classic
// ↑/↓ change page.
Surface {
    id: root

    name: "appearance"
    anchors.fill: parent

    readonly property var pages: [
        {id: "theme", label: "Theme", icon: "contrast", tint: Theme.lilac},
        {id: "accent", label: "Accent", icon: "colors", tint: Theme.rose},
        {id: "wallpaper", label: "Wallpaper", icon: "wallpaper", tint: Theme.ice},
        {id: "glass", label: "Glass", icon: "blur_on", tint: Theme.sage},
        {id: "dock", label: "Dock & bar", icon: "dock_to_bottom", tint: Theme.peach},
        {id: "keyboard", label: "Keyboard", icon: "keyboard", tint: Theme.ice},
        {id: "about", label: "About", icon: "info", tint: Theme.lilac}
    ]
    readonly property string page: DriftState.appearancePage

    function go(d: int): void {
        const i = pages.findIndex(p => p.id === page);
        DriftState.appearancePage = pages[Math.max(0, Math.min(pages.length - 1, i + d))].id;
    }

    Keys.onUpPressed: go(-1)
    Keys.onDownPressed: go(1)
    Keys.onTabPressed: go(1)
    Keys.onBacktabPressed: go(-1)

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    component Heading: Column {
        property alias kicker: k.text
        property alias title: t.text
        property alias sub: s.text

        spacing: 2
        bottomPadding: Theme.s4

        Kicker {
            id: k
        }

        Label {
            id: t

            size: Theme.title
            font.weight: Font.DemiBold
        }

        Label {
            id: s

            size: Theme.small
            secondary: true
        }
    }

    component Choice: Column {
        id: choice

        property string label
        property bool chosen
        property alias preview: frame.data
        signal picked

        spacing: 8

        Rectangle {
            id: frame

            width: 160
            height: 104
            radius: 16
            color: "transparent"
            clip: true
            border.width: choice.chosen ? 2.5 : 1
            border.color: choice.chosen ? Theme.accent : Theme.rimSoft

            MouseArea {
                anchors.fill: parent
                z: 10
                cursorShape: Qt.PointingHandCursor
                onClicked: choice.picked()
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: choice.label
            size: Theme.small
            font.weight: choice.chosen ? Font.DemiBold : Font.Normal
            color: choice.chosen ? Theme.text : Theme.textSecondary
        }
    }

    // a tiny mock desktop for the theme cards (the size of a Choice's frame)
    component Mini: Item {
        id: mini

        property bool darkLook

        width: 160
        height: 104

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: mini.darkLook ? "#24215A" : "#DDE4F8" }
                GradientStop { position: 1; color: mini.darkLook ? "#14132E" : "#F2D9E6" }
            }
        }

        Rectangle {
            x: 16
            y: 18
            width: 70
            height: 46
            radius: 9
            color: mini.darkLook ? Qt.rgba(0.2, 0.19, 0.38, 0.85) : Qt.rgba(1, 1, 1, 0.85)

            Rectangle {
                x: 8
                y: 9
                width: 34
                height: 5
                radius: 2.5
                color: mini.darkLook ? "#F2F3FA" : "#1B1F3B"
                opacity: 0.6
            }

            Rectangle {
                x: 8
                y: 20
                width: 50
                height: 5
                radius: 2.5
                color: Theme.accent
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: 64
            height: 10
            radius: 5
            color: mini.darkLook ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.8)
        }
    }

    component SettingRow: Item {
        property alias label: l.text
        property alias sub: d.text
        default property alias control: c.data

        width: parent?.width ?? 0
        height: 54

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Label {
                id: l

                font.weight: Font.Medium
            }

            Label {
                id: d

                visible: text !== ""
                size: Theme.small
                secondary: true
            }
        }

        Item {
            id: c

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Glass {
        id: sheet

        anchors.centerIn: parent
        width: 900
        height: 600
        color: Theme.sheet
        scale: 0.96 + 0.04 * root.progress

        MouseArea {
            anchors.fill: parent
        }

        // ── sidebar ──
        Column {
            id: side

            x: 14
            y: 18
            width: 196
            spacing: 2

            Label {
                leftPadding: 10
                bottomPadding: Theme.s3
                text: "Appearance"
                size: Theme.small
                font.weight: Font.DemiBold
                secondary: true
            }

            Repeater {
                model: root.pages

                ListRow {
                    required property var modelData

                    width: side.width
                    rowHeight: 38
                    icon: modelData.icon
                    iconTint: Qt.darker(modelData.tint, 1.6)
                    title: modelData.label
                    current: root.page === modelData.id
                    onClicked: DriftState.appearancePage = modelData.id
                }
            }
        }

        Rectangle {
            x: side.x + side.width + 12
            y: 14
            width: 1
            height: parent.height - 28
            color: Theme.divider
        }

        // ── content ──
        Item {
            id: content

            x: side.x + side.width + 40
            y: 26
            width: sheet.width - x - 32
            height: sheet.height - 52

            // Theme
            Column {
                visible: root.page === "theme"
                width: parent.width

                Heading {
                    kicker: "Personalization · theme"
                    title: "Theme"
                    sub: "Light, dark — or let the sun decide."
                }

                Row {
                    spacing: Theme.s4

                    Choice {
                        label: "Light"
                        chosen: DriftConfig.theme === "light"
                        onPicked: DriftConfig.set("theme", "light")
                        preview: Mini { darkLook: false }
                    }

                    Choice {
                        label: "Dark"
                        chosen: DriftConfig.theme === "dark"
                        onPicked: DriftConfig.set("theme", "dark")
                        preview: Mini { darkLook: true }
                    }

                    Choice {
                        label: "Auto"
                        chosen: DriftConfig.theme === "auto"
                        onPicked: DriftConfig.set("theme", "auto")
                        // light on the left, dark on the right
                        preview: [
                            Mini { darkLook: false },
                            Item {
                                x: 80
                                width: 80
                                height: 104
                                clip: true

                                Mini {
                                    x: -80
                                    darkLook: true
                                }
                            }
                        ]
                    }
                }

                Label {
                    topPadding: Theme.s4
                    width: parent.width
                    text: DriftConfig.theme === "auto" ? `Auto: dark from sunset (${Weather.sunset}) to sunrise (${Weather.sunrise}). It is ${Theme.dark ? "dark" : "light"} now.` : "Every change applies at once, no restart."
                    size: Theme.small
                    secondary: true
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: 1
                    height: Theme.s4
                }

                SettingRow {
                    label: "COSMIC apps follow"
                    sub: "Files, Terminal and Settings switch between light and dark with Drift"

                    Toggle {
                        checked: DriftConfig.cosmicSync
                        onToggled: c => DriftConfig.set("cosmicSync", c)
                    }
                }
            }

            // Accent
            Column {
                visible: root.page === "accent"
                width: parent.width
                spacing: Theme.s5

                Heading {
                    kicker: "Personalization · accent"
                    title: "Accent color"
                    sub: "Pick a color. It shows up everywhere."
                    bottomPadding: 0
                }

                Row {
                    spacing: 14

                    Repeater {
                        model: Theme.accentNames

                        Rectangle {
                            id: sw

                            required property string modelData

                            width: 44
                            height: 44
                            radius: 22
                            color: Theme.accents[modelData]
                            border.width: DriftConfig.accent === modelData ? 3 : 0
                            border.color: Theme.dark ? "#1C1B3A" : "#FFFFFF"
                            scale: swArea.containsMouse ? 1.08 : 1

                            Behavior on scale {
                                Anim { duration: Theme.fast }
                            }

                            Rectangle {
                                visible: DriftConfig.accent === sw.modelData
                                anchors.centerIn: parent
                                width: parent.width + 8
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: sw.color
                            }

                            MouseArea {
                                id: swArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DriftConfig.set("accent", sw.modelData)
                            }
                        }
                    }
                }

                Tile {
                    width: parent.width
                    height: 92
                    interactive: false

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 22

                        Toggle {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: true
                            onToggled: c => checked = c
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 110
                            height: 34
                            radius: 17
                            color: Theme.accent

                            Label {
                                anchors.centerIn: parent
                                text: "Continue"
                                color: "#FFFFFF"
                                font.weight: Font.DemiBold
                            }
                        }

                        Slider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 220
                            value: 0.7
                            onMoved: v => value = v
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "favorite"
                            active: true
                        }
                    }
                }
            }

            // Wallpaper
            Column {
                visible: root.page === "wallpaper"
                width: parent.width

                Heading {
                    kicker: "Personalization · wallpaper"
                    title: "Wallpaper"
                    sub: "Glass sails — in every mood."
                }

                Grid {
                    columns: 3
                    spacing: Theme.s4

                    Repeater {
                        model: Moods.names

                        Choice {
                            id: mood

                            required property string modelData

                            label: Moods.labels[modelData]
                            chosen: DriftConfig.wallpaper === modelData
                            onPicked: DriftConfig.set("wallpaper", modelData)
                            preview: [
                                Sails {
                                    visible: mood.modelData !== "system"
                                    anchors.fill: parent
                                    mood: mood.modelData
                                    living: false
                                    darken: false
                                },
                                Rectangle {
                                    visible: mood.modelData === "system"
                                    anchors.fill: parent
                                    color: Theme.well

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Icon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: "image"
                                            size: 24
                                            color: Theme.textSecondary
                                        }

                                        Label {
                                            text: "COSMIC's own"
                                            size: Theme.caption + 1
                                            secondary: true
                                        }
                                    }
                                }
                            ]
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.s3
                }

                SettingRow {
                    label: "Living wallpaper"
                    sub: DriftConfig.living ? `Follows the time of day — now: ${Moods.partOfDay().toLowerCase()}` : "Always the same light"

                    Toggle {
                        checked: DriftConfig.living
                        onToggled: c => DriftConfig.set("living", c)
                    }
                }
            }

            // Glass
            Column {
                visible: root.page === "glass"
                width: parent.width
                spacing: Theme.s3

                Heading {
                    kicker: "Personalization · glass"
                    title: "Glass"
                    sub: "As clear or as frosted as you like."
                    bottomPadding: Theme.s2
                }

                Row {
                    width: parent.width

                    Label {
                        width: 120
                        text: "Transparency"
                    }

                    Slider {
                        width: parent.width - 170
                        value: DriftConfig.transparency
                        onMoved: v => DriftConfig.set("transparency", v)
                    }

                    Label {
                        width: 50
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(DriftConfig.transparency * 100)}%`
                        secondary: true
                    }
                }

                Row {
                    width: parent.width

                    Label {
                        width: 120
                        text: "Frost"
                    }

                    Slider {
                        width: parent.width - 170
                        value: DriftConfig.frost
                        onMoved: v => DriftConfig.set("frost", v)
                    }

                    Label {
                        width: 50
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(DriftConfig.frost * 100)}%`
                        secondary: true
                    }
                }

                // live preview: a pane of glass over the sails
                Rectangle {
                    width: parent.width
                    height: 200
                    radius: 20
                    clip: true
                    color: "transparent"

                    Sails {
                        anchors.fill: parent
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.62
                        height: 96
                        radius: 22
                        color: Theme.pane
                        border.width: 1
                        border.color: Theme.rimSoft

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.haze
                        }

                        Label {
                            anchors.centerIn: parent
                            text: "Glass"
                            size: Theme.heading
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Label {
                    width: parent.width
                    text: "Frost below 5% turns the blur behind panels off."
                    size: Theme.small
                    muted: true
                }
            }

            // Dock & bar
            Column {
                visible: root.page === "dock"
                width: parent.width

                Heading {
                    kicker: "Personalization · dock & bar"
                    title: "Dock & side bar"
                    sub: "Keep them — or go keyboard-only."
                }

                Label {
                    text: "Dock"
                    font.weight: Font.Medium
                    bottomPadding: Theme.s2
                }

                Segmented {
                    width: parent.width
                    options: ["autohide", "always", "off"]
                    labels: ["Auto-hide", "Always", "Off"]
                    accentFill: true
                    current: DriftConfig.dock
                    onPicked: o => DriftConfig.set("dock", o)
                }

                Label {
                    topPadding: Theme.s5
                    text: "Side bar"
                    font.weight: Font.Medium
                    bottomPadding: Theme.s2
                }

                Segmented {
                    width: parent.width
                    options: ["full", "minimal"]
                    labels: ["Full", "Minimal"]
                    accentFill: true
                    current: DriftConfig.bar
                    onPicked: o => DriftConfig.set("bar", o)
                }

                Item {
                    width: 1
                    height: Theme.s3
                }

                SettingRow {
                    label: "Gaps between windows"
                    sub: "Off: tiled windows fill the screen like a maximized one"

                    Toggle {
                        checked: DriftConfig.windowGaps
                        onToggled: c => DriftConfig.set("windowGaps", c)
                    }
                }

                Label {
                    topPadding: Theme.s3
                    text: "Deep Focus session"
                    font.weight: Font.Medium
                    bottomPadding: Theme.s2
                }

                Segmented {
                    width: parent.width
                    options: ["25", "50", "90"]
                    labels: ["25 min", "50 min", "90 min"]
                    accentFill: true
                    current: String(DriftConfig.focusMinutes)
                    onPicked: o => DriftConfig.set("focusMinutes", parseInt(o))
                }
            }

            // Keyboard
            Column {
                visible: root.page === "keyboard"
                width: parent.width
                spacing: 2

                Heading {
                    kicker: "Keyboard first"
                    title: "Everything has a shortcut"
                    sub: "Super+Shift+/ shows this list anywhere."
                }

                Repeater {
                    model: [["Command bar", "Super", "Space"], ["Control Center", "Super", "C"], ["Window hints", "Super", "E"], ["Desks", "Super", "W"], ["Clipboard", "Super", "V"], ["Appearance", "Super", "P"], ["Deep Focus", "Super", "Shift", "F"], ["Lock", "Super", "L"]]

                    Item {
                        id: sc

                        required property var modelData

                        width: parent.width
                        height: 36

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: sc.modelData[0]
                            secondary: true
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Repeater {
                                model: sc.modelData.slice(1)

                                Keycap {
                                    required property string modelData

                                    key: modelData
                                }
                            }
                        }
                    }
                }
            }

            // About
            Column {
                visible: root.page === "about"
                width: parent.width
                spacing: Theme.s4

                Heading {
                    kicker: "About"
                    title: "JellyFace · Drift"
                    sub: "Simple. Fluid. Yours. — JellyFace's second interface, next to Classic."
                    bottomPadding: 0
                }

                Rectangle {
                    width: parent.width
                    height: 150
                    radius: 20
                    clip: true
                    color: "transparent"

                    Sails {
                        anchors.fill: parent
                    }

                    Label {
                        anchors.centerIn: parent
                        text: "Drift"
                        size: 56
                        font.weight: Font.DemiBold
                        font.letterSpacing: -2
                        color: Theme.dark ? "#FFFFFF" : "#1B1F3B"
                    }
                }

                Row {
                    spacing: Theme.s3

                    Pill {
                        height: 38
                        interactive: true
                        padding: 16
                        onClicked: Quickshell.execDetached(["distrobox-host-exec", Quickshell.shellPath("../bin/jellyface"), "ui", "classic"])

                        Icon { name: "swap_horiz"; size: 17; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "Switch to Classic"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Pill {
                        height: 38
                        interactive: true
                        padding: 16
                        onClicked: DriftState.show("gallery")

                        Icon { name: "auto_awesome"; size: 17; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "Style gallery"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Label {
                    width: parent.width
                    text: "Settings live in ~/.config/jellyface/drift.json. Run “jellyface ui classic” to go back at any time."
                    size: Theme.small
                    muted: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
