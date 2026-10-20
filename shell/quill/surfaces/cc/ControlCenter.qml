pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.quill
import qs.quill.components

// Control Center (Super+C, or a status icon on the side bar, which opens its page). A grid of glass tiles:
//   Wi-Fi / Bluetooth · Focus · volume and brightness · quick actions and battery · now playing · notifications
// Clicking a tile (or Enter on it) grows it, from where it sits, into its detail view; ‹ or Esc folds it back.
// Keyboard: arrows move the focus ring between tiles (left/right adjust a slider), Enter opens, Esc goes back/closes.
Surface {
    id: root

    name: "cc"
    anchors.fill: parent

    readonly property string page: QuillState.ccPage
    property string lastPage
    readonly property int pad: 12
    readonly property int gap: 8
    readonly property int sheetWidth: 580
    readonly property int colWidth: (sheetWidth - pad * 2 - gap) / 2
    property int focusIndex: -1 // keyboard focus ring (-1: none until an arrow is pressed)

    readonly property var brightness: Brightness.getMonitorForScreen(Quickshell.screens[0])
    readonly property var player: Players.active

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    // ── keyboard ──
    readonly property var targets: [
        {item: wifiRow, open: "wifi"},
        {item: btRow, open: "bluetooth"},
        {item: focusTile, open: "focus"},
        {item: volume, open: "sound", slider: volume},
        {item: bright, slider: bright},
        {item: q0, press: () => q0.clicked()},
        {item: q1, press: () => q1.clicked()},
        {item: q2, press: () => q2.clicked()},
        {item: q3, press: () => q3.clicked()},
        {item: q4, press: () => q4.clicked()},
        {item: batteryRow, open: "battery"},
        {item: mediaTile, press: () => root.player?.togglePlaying()},
        {item: notifTile, open: "notifications"}
    ].filter(t => t.item.visible)
    readonly property Item focusItem: focusIndex >= 0 && focusIndex < targets.length ? targets[focusIndex].item : null

    function nav(dx: int, dy: int): void {
        if (focusIndex < 0) {
            focusIndex = 0;
            return;
        }
        const from = targets[focusIndex].item;
        const c = from.mapToItem(grid, from.width / 2, from.height / 2);
        let best = -1, bestScore = Infinity;
        targets.forEach((t, i) => {
            if (i === focusIndex)
                return;
            const p = t.item.mapToItem(grid, t.item.width / 2, t.item.height / 2);
            const along = dx !== 0 ? (p.x - c.x) * dx : (p.y - c.y) * dy;
            const across = dx !== 0 ? Math.abs(p.y - c.y) : Math.abs(p.x - c.x);
            if (along <= 4)
                return;
            const score = along + across * 2.5;
            if (score < bestScore) {
                bestScore = score;
                best = i;
            }
        });
        if (best >= 0)
            focusIndex = best;
    }

    function pressFocused(): void {
        const t = targets[focusIndex];
        if (!t)
            return;
        if (t.open)
            QuillState.ccPage = t.open;
        else
            t.press?.();
    }

    Keys.onPressed: e => {
        if (root.page !== "") {
            const p = detail.page;
            if (e.key === Qt.Key_Escape || e.key === Qt.Key_Backspace && !(p?.asking)) {
                QuillState.ccPage = "";
            } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
                p?.move?.(-1);
            } else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) {
                p?.move?.(1);
            } else if (e.key === Qt.Key_Left) {
                p?.move?.(-1);
            } else if (e.key === Qt.Key_Right) {
                p?.move?.(1);
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                p?.enter?.();
            } else {
                return;
            }
            e.accepted = true;
            return;
        }
        const slider = root.targets[root.focusIndex]?.slider;
        if (e.key === Qt.Key_Escape)
            QuillState.close();
        else if (e.key === Qt.Key_Left)
            slider ? slider.step(-0.05) : root.nav(-1, 0);
        else if (e.key === Qt.Key_Right)
            slider ? slider.step(0.05) : root.nav(1, 0);
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab)
            root.nav(0, -1);
        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab)
            root.nav(0, 1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            root.pressFocused();
        else
            return;
        e.accepted = true;
    }

    onActiveChanged: if (!active) focusIndex = -1
    // a tile that disappears (the media tile when the player closes) must not leave the ring on nothing
    onTargetsChanged: if (focusIndex >= targets.length) focusIndex = targets.length - 1

    // ── expand in place ──
    function sourceOf(p: string): Item {
        return ({
                wifi: wifiRow,
                bluetooth: btRow,
                focus: focusTile,
                sound: slidersTile,
                battery: quickTile,
                notifications: notifTile
            })[p] ?? grid;
    }

    function rectOf(item: Item): rect {
        const p = item.mapToItem(sheet.body, 0, 0);
        return Qt.rect(p.x, p.y, item.width, item.height);
    }

    onPageChanged: {
        if (page !== "") {
            lastPage = page;
            const r = rectOf(sourceOf(page));
            detail.animate = false;
            detail.x = r.x;
            detail.y = r.y;
            detail.width = r.width;
            detail.height = r.height;
            detail.opened = true;
            Qt.callLater(() => {
                detail.animate = true;
                detail.x = root.pad;
                detail.y = root.pad;
                detail.width = root.sheetWidth - root.pad * 2;
                detail.height = Qt.binding(() => detail.fullHeight);
            });
        } else if (lastPage !== "") {
            const r = rectOf(sourceOf(lastPage));
            detail.animate = true;
            detail.opened = false;
            detail.x = r.x;
            detail.y = r.y;
            detail.width = r.width;
            detail.height = r.height;
        }
    }

    Glass {
        id: sheet

        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 78 // beside the side bar
        width: root.sheetWidth
        height: (root.page !== "" ? Math.max(grid.implicitHeight, detail.fullHeight) : grid.implicitHeight) + root.pad * 2
        color: Theme.sheet
        scale: 0.96 + 0.04 * root.progress
        transformOrigin: Item.TopLeft

        Behavior on height {
            Anim { duration: Theme.slow }
        }

        MouseArea {
            anchors.fill: parent
        }

        // ── the grid ──
        Column {
            id: grid

            x: root.pad
            y: root.pad
            width: root.sheetWidth - root.pad * 2
            spacing: root.gap
            opacity: root.page !== "" ? 0.18 : 1
            enabled: root.page === ""

            Behavior on opacity {
                Anim {}
            }

            Row {
                spacing: root.gap

                // left column: connectivity, then sound and light
                Column {
                    spacing: root.gap

                    Tile {
                        id: connTile

                        width: root.colWidth
                        height: 112
                        interactive: false

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            ConnRow {
                                id: wifiRow

                                icon: Nmcli.activeEthernet ? "lan" : Nmcli.wifiEnabled ? "wifi" : "wifi_off"
                                on: Nmcli.wifiEnabled || !!Nmcli.activeEthernet
                                title: Nmcli.activeEthernet && !Nmcli.active ? "Ethernet" : "Wi-Fi"
                                subtitle: Nmcli.active?.ssid ?? (Nmcli.activeEthernet ? "Connected" : Nmcli.wifiEnabled ? "Not connected" : "Off")
                                onToggle: Nmcli.enableWifi(!Nmcli.wifiEnabled)
                                onOpen: QuillState.ccPage = "wifi"
                            }

                            ConnRow {
                                id: btRow

                                readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

                                icon: Bluetooth.defaultAdapter?.enabled ? "bluetooth" : "bluetooth_disabled"
                                on: !!Bluetooth.defaultAdapter?.enabled
                                title: "Bluetooth"
                                subtitle: !Bluetooth.defaultAdapter?.enabled ? "Off" : connected.length > 0 ? connected.map(d => d.name).join(", ") : "On"
                                onToggle: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                                onOpen: QuillState.ccPage = "bluetooth"
                            }
                        }
                    }

                    Tile {
                        id: slidersTile

                        width: root.colWidth
                        height: 92
                        interactive: false

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            anchors.topMargin: 16
                            spacing: 14

                            Row {
                                width: parent.width
                                spacing: 4

                                Slider {
                                    id: volume

                                    function step(d: real): void {
                                        Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + d)));
                                    }

                                    width: parent.width - soundMore.width - 4
                                    icon: Audio.muted ? "no_sound" : Audio.volume > 0.5 ? "volume_up" : "volume_down"
                                    value: Audio.volume
                                    onMoved: v => Audio.setVolume(v)
                                }

                                Icon {
                                    id: soundMore

                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "chevron_right"
                                    size: 18
                                    color: soundMoreArea.containsMouse ? Theme.accent : Theme.textSecondary

                                    MouseArea {
                                        id: soundMoreArea

                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: QuillState.ccPage = "sound"
                                    }
                                }
                            }

                            Slider {
                                id: bright

                                function step(d: real): void {
                                    root.brightness?.setBrightness(Math.max(0.01, Math.min(1, (root.brightness?.brightness ?? 0) + d)));
                                }

                                width: parent.width - 22
                                icon: "light_mode"
                                enabled: !!root.brightness
                                value: root.brightness?.brightness ?? 0
                                onMoved: v => root.brightness?.setBrightness(Math.max(0.01, v))
                            }
                        }
                    }
                }

                // right column: focus, then quick actions and battery
                Column {
                    spacing: root.gap

                    Tile {
                        id: focusTile

                        width: root.colWidth
                        height: 56
                        selected: DeepFocus.active || Notifs.dnd
                        onClicked: QuillState.ccPage = "focus"

                        Rectangle {
                            id: moon

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 16
                            color: focusTile.selected ? Theme.accent : moonArea.containsMouse ? Theme.tileHover : Theme.well
                            scale: moonArea.pressed ? 0.9 : 1

                            Behavior on color {
                                ColorAnim { duration: Theme.fast }
                            }
                            Behavior on scale {
                                Anim { duration: Theme.fast }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: "bedtime"
                                size: 17
                                filled: focusTile.selected
                                color: focusTile.selected ? "#FFFFFF" : Theme.text
                            }

                            MouseArea {
                                id: moonArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.dnd = !Notifs.dnd
                            }
                        }

                        Column {
                            anchors.left: moon.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                text: "Focus"
                                font.weight: Font.Medium
                            }

                            Label {
                                text: DeepFocus.active ? `Deep Focus · ${DeepFocus.remainingText}` : Notifs.dnd ? "Do Not Disturb" : "Off"
                                size: Theme.small
                                secondary: true
                            }
                        }
                    }

                    Tile {
                        id: quickTile

                        width: root.colWidth
                        height: 148
                        interactive: false

                        Row {
                            id: quick

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 14
                            spacing: 9

                            IconButton {
                                id: q0

                                size: 42
                                icon: Theme.dark ? "dark_mode" : "light_mode"
                                active: Theme.dark
                                onClicked: QuillConfig.set("theme", Theme.dark ? "light" : "dark")
                            }

                            IconButton {
                                id: q1

                                size: 42
                                icon: "coffee"
                                active: IdleInhibitor.enabled
                                onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
                            }

                            IconButton {
                                id: q2

                                size: 42
                                icon: "screenshot_region"
                                onClicked: {
                                    QuillState.close();
                                    Quickshell.execDetached(["distrobox-host-exec", "cosmic-screenshot"]);
                                }
                            }

                            IconButton {
                                id: q3

                                size: 42
                                icon: "tune"
                                onClicked: QuillState.show("appearance")
                            }

                            IconButton {
                                id: q4

                                size: 42
                                icon: "power_settings_new"
                                onClicked: QuillState.show("session")
                            }
                        }

                        // battery (or the power profile without one)
                        Rectangle {
                            id: batteryRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            height: 56
                            radius: Theme.radiusRow
                            color: batteryArea.containsMouse ? Theme.tileHover : "transparent"

                            Behavior on color {
                                ColorAnim { duration: Theme.fast }
                            }

                            MouseArea {
                                id: batteryArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: QuillState.ccPage = "battery"
                            }

                            Label {
                                id: pct

                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: Power.present ? `${Math.round(Power.percent * 100)}%` : "Power"
                                size: Theme.small
                                font.weight: Font.DemiBold
                                width: 40
                            }

                            Rectangle {
                                visible: Power.present
                                anchors.left: pct.right
                                anchors.right: plug.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                height: 6
                                radius: 3
                                color: Theme.well

                                Rectangle {
                                    width: parent.width * Power.percent
                                    height: parent.height
                                    radius: 3
                                    color: Power.percent <= 0.2 && !Power.charging ? Theme.bad : Theme.good

                                    Behavior on width {
                                        Anim {}
                                    }
                                }
                            }

                            Label {
                                visible: !Power.present
                                anchors.left: pct.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Power.profile ? Power.profile[0].toUpperCase() + Power.profile.slice(1) : ""
                                size: Theme.small
                                secondary: true
                            }

                            Icon {
                                id: plug

                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                name: Power.charging || Power.full ? "power" : "chevron_right"
                                size: 16
                                color: Theme.textSecondary
                            }
                        }
                    }
                }
            }

            // now playing
            Tile {
                id: mediaTile

                visible: !!root.player
                width: parent.width
                height: 72
                interactive: false

                Rectangle {
                    id: art

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    radius: 12
                    color: Theme.lilac
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? Players.getArtUrl(root.player) : ""
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 12
                    anchors.right: controls.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        width: parent.width
                        text: root.player?.trackTitle || "Nothing playing"
                        font.weight: Font.Medium
                    }

                    Label {
                        width: parent.width
                        text: root.player?.trackArtist || Players.getIdentity(root.player)
                        size: Theme.small
                        secondary: true
                    }
                }

                Row {
                    id: controls

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    IconButton {
                        size: 34
                        icon: "skip_previous"
                        onClicked: root.player?.previous()
                    }

                    IconButton {
                        size: 40
                        icon: root.player?.isPlaying ? "pause" : "play_arrow"
                        active: true
                        onClicked: root.player?.togglePlaying()
                    }

                    IconButton {
                        size: 34
                        icon: "skip_next"
                        onClicked: root.player?.next()
                    }
                }
            }

            // notifications (the three newest)
            Tile {
                id: notifTile

                readonly property var latest: [...Notifs.notClosed].reverse().slice(0, 3)

                width: parent.width
                height: 44 + (latest.length > 0 ? latest.length * 52 + 6 : 0)
                onClicked: QuillState.ccPage = "notifications"

                Behavior on height {
                    Anim {}
                }

                Row {
                    x: 14
                    y: 12
                    spacing: 8

                    Icon {
                        name: Notifs.dnd ? "notifications_off" : "notifications"
                        size: 17
                    }

                    Label {
                        text: Notifs.notClosed.length > 0 ? `Notifications · ${Notifs.notClosed.length}` : Notifs.dnd ? "Do Not Disturb is on" : "No notifications"
                        font.weight: Font.Medium
                    }
                }

                Icon {
                    x: parent.width - width - 14
                    y: 12
                    name: "chevron_right"
                    size: 18
                    color: Theme.textSecondary
                }

                Column {
                    x: 8
                    y: 42
                    width: parent.width - 16
                    spacing: 2

                    Repeater {
                        model: ScriptModel {
                            values: notifTile.latest
                        }

                        Rectangle {
                            id: n

                            required property var modelData

                            width: parent.width
                            height: 50
                            radius: Theme.radiusRow
                            color: nArea.containsMouse ? Theme.tileHover : "transparent"

                            Behavior on color {
                                ColorAnim { duration: Theme.fast }
                            }

                            MouseArea {
                                id: nArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = n.modelData.actions?.find(a => a.identifier === "default") ?? (n.modelData.actions?.length === 1 ? n.modelData.actions[0] : null);
                                    a?.invoke();
                                    n.modelData.close();
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter

                                Label {
                                    width: parent.width
                                    text: `${n.modelData.summary}`
                                    font.weight: Font.Medium
                                }

                                Label {
                                    width: parent.width
                                    text: `${n.modelData.appName} · ${n.modelData.timeStr}${n.modelData.body ? " — " + n.modelData.body.replace(/<[^>]*>/g, "").replace(/\n/g, " ") : ""}`
                                    size: Theme.small
                                    secondary: true
                                }
                            }
                        }
                    }
                }
            }
        }

        // the keyboard focus ring, gliding from tile to tile
        Rectangle {
            readonly property rect r: root.focusItem ? root.rectOf(root.focusItem) : Qt.rect(0, 0, 0, 0)

            visible: !!root.focusItem && root.page === ""
            x: r.x - 3
            y: r.y - 3
            width: r.width + 6
            height: r.height + 6
            radius: (root.focusItem?.radius ?? Theme.radiusRow) + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.accent

            Behavior on x { Anim { duration: Theme.normal } }
            Behavior on y { Anim { duration: Theme.normal } }
            Behavior on width { Anim { duration: Theme.normal } }
            Behavior on height { Anim { duration: Theme.normal } }
        }

        // ── the detail view, grown out of its tile ──
        Rectangle {
            id: detail

            property bool animate
            property bool opened
            readonly property Item page: loader.item
            readonly property real fullHeight: Math.min(560, (loader.item?.implicitHeight ?? 200) + root.pad * 2)

            visible: opened || moving.running
            radius: opened ? Theme.radiusTile + 4 : Theme.radiusTile
            color: Theme.dark ? Qt.rgba(0.17, 0.16, 0.33, 0.96) : Qt.rgba(1, 1, 1, 0.94)
            border.width: 1
            border.color: Theme.rimSoft
            clip: true

            Behavior on x {
                enabled: detail.animate
                Anim { id: moving; duration: Theme.slow }
            }
            Behavior on y {
                enabled: detail.animate
                Anim { duration: Theme.slow }
            }
            Behavior on width {
                enabled: detail.animate
                Anim { duration: Theme.slow }
            }
            Behavior on height {
                enabled: detail.animate
                Anim { duration: Theme.slow }
            }
            Behavior on radius {
                Anim { duration: Theme.slow }
            }

            Loader {
                id: loader

                x: root.pad
                y: root.pad - 4
                width: root.sheetWidth - root.pad * 4
                opacity: detail.opened ? 1 : 0
                active: root.lastPage !== ""
                source: ({
                        wifi: "WifiPage.qml",
                        bluetooth: "BluetoothPage.qml",
                        focus: "FocusPage.qml",
                        sound: "SoundPage.qml",
                        battery: "BatteryPage.qml",
                        notifications: "NotificationsPage.qml"
                    })[root.lastPage] ?? ""

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: detail.opened ? 90 : 0 }
                        Anim { duration: detail.opened ? Theme.normal : Theme.fast }
                    }
                }
            }
        }
    }

    // one row of the connectivity tile: a round toggle, the name and its state; the row opens the detail view
    component ConnRow: Rectangle {
        id: row

        property string icon
        property bool on
        property string title
        property string subtitle
        signal toggle
        signal open

        width: root.colWidth - 12
        height: 48
        radius: Theme.radiusRow
        color: rowArea.containsMouse ? Theme.tileHover : "transparent"

        Behavior on color {
            ColorAnim { duration: Theme.fast }
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.open()
        }

        Rectangle {
            id: dot

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: row.on ? (dotArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : dotArea.containsMouse ? Theme.tileHover : Theme.well
            scale: dotArea.pressed ? 0.9 : 1

            Behavior on color {
                ColorAnim { duration: Theme.fast }
            }
            Behavior on scale {
                Anim { duration: Theme.fast }
            }

            Icon {
                anchors.centerIn: parent
                name: row.icon
                size: 17
                filled: row.on
                color: row.on ? "#FFFFFF" : Theme.text
            }

            MouseArea {
                id: dotArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggle()
            }
        }

        Column {
            anchors.left: dot.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: row.title
                font.weight: Font.Medium
            }

            Label {
                width: parent.width
                text: row.subtitle
                size: Theme.small
                secondary: true
            }
        }
    }
}
