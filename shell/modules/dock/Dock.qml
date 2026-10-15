pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Jellyface.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import "."

// JellyFace Dock & Desktop Widget Ecosystem:
// 1. Original Bottom Dock: Glass capsule at the bottom centre of the screen with auto-hide,
//    hover magnification, drag-to-reorder, and running window indicators.
// 2. Desktop Dashboard: Clean 2-column modular widgets (CommandBar, System Monitor, Notifications, Mail)
//    anchored to the desktop wallpaper on WlrLayer.Bottom.
Scope {
    id: root

    property ListModel apps: ListModel {}
    property var extra: ({})
    property string lastWritten
    readonly property int count: apps.count

    property string popup
    property int popupIndex: -1
    property point popupAnchor
    property bool dragging

    readonly property var symbols: [
        [["youtube"], "smart_display"],
        [["pinterest"], "push_pin"],
        [["chatgpt", "openai"], "smart_toy"],
        [["claude"], "asterisk"],
        [["gemini"], "auto_awesome"],
        [["github.com", "gitlab.com"], "commit"],
        [["whatsapp", "telegram", "signal", "messag"], "chat"],
        [["gmail", "mail", "thunderbird", "evolution"], "mail"],
        [["discord", "slack", "teams"], "forum"],
        [["spotify", "music", "rhythmbox"], "music_note"],
        [["obsidian"], "diamond"],
        [["visual studio", "vscode", "code", "zed", "jetbrains"], "code_blocks"],
        [["sublime", "text editor", "gedit", "kate", "notes"], "edit_note"],
        [["kooha", "obs", "record"], "screen_record"],
        [["screenshot"], "screenshot_region"],
        [["monitor", "htop", "resources"], "monitoring"],
        [["baobab", "disk usage"], "pie_chart"],
        [["disks", "gparted"], "hard_drive"],
        [["terminal", "term", "console", "konsole", "kitty", "alacritty", "ghostty"], "terminal"],
        [["files", "nautilus", "dolphin", "thunar", "nemo"], "folder"],
        [["settings", "control center"], "settings"],
        [["store", "software", "flathub"], "storefront"],
        [["firefox", "brave", "chrom", "browser", "vivaldi", "zen"], "language"],
        [["vlc", "mpv", "video", "player", "celluloid"], "play_circle"],
        [["calendar"], "calendar_month"],
        [["calculator"], "calculate"],
        [["image", "photo", "viewer", "loupe"], "image"],
        [["camera"], "photo_camera"],
        [["writer", "document"], "description"],
        [["calc", "sheet"], "table"],
        [["impress", "slides", "presentation"], "slideshow"],
        [["steam", "game", "lutris"], "sports_esports"],
        [["maps"], "map"],
        [["weather"], "partly_cloudy_day"]
    ]

    function symbolFor(text: string): string {
        const t = text.toLowerCase();
        for (const [words, symbol] of symbols)
            if (words.some(w => t.includes(w)))
                return symbol;
        return "";
    }

    function appAt(i: int): var {
        return i >= 0 && i < apps.count ? JSON.parse(apps.get(i).json) : null;
    }

    function windowsOf(app: var): var {
        if (!app)
            return [];
        const entry = app.id ? DesktopEntries.heuristicLookup(app.id) : null;
        const ids = [app.id, entry?.startupClass, entry?.id].filter(x => x).map(x => x.toLowerCase().replace(/\.desktop$/, ""));
        if (app.id)
            ids.push(app.id.split(".").pop().toLowerCase());
        return CosmicWindows.windows.filter(w => {
            const cls = (w.app_id ?? "").toLowerCase();
            return app.match ? cls.includes(app.match.toLowerCase()) : ids.includes(cls);
        });
    }

    function launch(app: var): void {
        if (app.command)
            Quickshell.execDetached(["distrobox-host-exec", "sh", "-c", app.command]);
        else
            Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", app.id]);
    }

    function open(app: var): void {
        JellyPanel.open = false;
        const wins = windowsOf(app);
        if (wins.length > 0) {
            const at = wins.findIndex(w => w.id === CosmicWindows.activeId);
            CosmicWindows.activate(wins[(at + 1) % wins.length].id);
        } else {
            launch(app);
        }
    }

    function closeAll(app: var): void {
        for (const w of windowsOf(app))
            CosmicWindows.close(w.id);
    }

    function has(app: var): bool {
        for (let i = 0; i < apps.count; i++) {
            const a = appAt(i);
            if ((app.id && a.id === app.id) || (app.match && a.match === app.match))
                return true;
        }
        return false;
    }

    function add(app: var): void {
        if (!has(app)) {
            apps.append({json: JSON.stringify(app)});
            save();
        }
    }

    function remove(i: int): void {
        if (i >= 0 && i < apps.count) {
            apps.remove(i);
            save();
        }
    }

    function move(from: int, to: int): void {
        to = Math.max(0, Math.min(apps.count - 1, to));
        if (from !== to && from >= 0 && from < apps.count) {
            apps.move(from, to, 1);
            save();
        }
    }

    function save(): void {
        const list = [];
        for (let i = 0; i < apps.count; i++)
            list.push(appAt(i));
        lastWritten = JSON.stringify(Object.assign({}, extra, {apps: list}), null, 4) + "\n";
        file.setText(lastWritten);
    }

    function load(text: string): void {
        if (text === lastWritten)
            return;
        try {
            const d = JSON.parse(text);
            const list = d.apps ?? [];
            delete d.apps;
            extra = d;
            apps.clear();
            for (const a of list)
                apps.append({json: JSON.stringify(a)});
        } catch (e) {
            console.warn("dock.json is not valid JSON:", e);
        }
    }

    function openPopup(kind: string, index: int, item: Item): void {
        popupIndex = index;
        if (item) {
            const p = item.mapToItem(win.contentItem, item.width / 2, 0);
            const s = win.screen;
            popupAnchor = Qt.point((s.width - win.width) / 2 + p.x, s.height - win.margins.bottom - win.height + p.y);
        }
        popup = kind;
    }

    FileView {
        id: file

        path: `${Paths.config}/dock.json`
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.load(text())
    }

    DockPopups {
        dock: root
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // 1. Original Bottom Dock Window (Floating Glass Capsule)
    // ─────────────────────────────────────────────────────────────────────────────
    StyledWindow {
        id: win

        screen: Quickshell.screens[0]
        name: "dock"
        WlrLayershell.layer: JellyPanel.open ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.bottom: true
        margins.bottom: Math.max(contentItem.Tokens.padding.small, contentItem.Config.border.thickness) + contentItem.Tokens.padding.extraLargeIncreased

        implicitWidth: panel.fullWidth
        implicitHeight: panel.fullHeight + panel.lift
        mask: Region {
            item: panel
        }

        BackgroundEffect.blurRegion: Glass.enabled ? dockBlur : null

        Region {
            id: dockBlur

            GlassRegion {
                pane: tip
            }
        }

        readonly property rect dockRect: Qt.rect(((screen?.width ?? 1920) - panel.fullWidth) / 2, (screen?.height ?? 1080) - margins.bottom - panel.fullHeight, panel.fullWidth, panel.fullHeight)
        readonly property bool covered: CosmicWindows.fullscreen || CosmicWindows.windows.some(w => w.workspace_active && !w.minimized && w.w > 0 && w.x < dockRect.x + dockRect.width && w.x + w.w > dockRect.x && w.y < dockRect.y + dockRect.height && w.y + w.h > dockRect.y)
        readonly property bool wanted: JellyPanel.open || !covered || hover.hovered || DockReveal.edge || root.popup !== "" || root.dragging
        property bool shown: true

        Component.onCompleted: if (!wanted) hideTimer.restart()
        onWantedChanged: {
            if (wanted) {
                hideTimer.stop();
                shown = true;
            } else {
                hideTimer.restart();
            }
        }

        Timer {
            id: hideTimer

            interval: 450
            onTriggered: win.shown = win.wanted
        }

        Binding {
            target: DockReveal
            property: "left"
            value: win.dockRect.x
        }

        Binding {
            target: DockReveal
            property: "right"
            value: win.dockRect.x + win.dockRect.width
        }

        StyledRect {
            id: tip

            readonly property bool wanted: panel.tipLabel !== "" && win.shown && !root.dragging && root.popup === ""
            property bool showing

            onWantedChanged: {
                if (wanted) {
                    tipTimer.restart();
                } else {
                    tipTimer.stop();
                    showing = false;
                }
            }

            x: Math.max(0, Math.min(win.width - width, panel.tipX - width / 2))
            y: panel.y - height - 14
            implicitWidth: tipText.implicitWidth + Tokens.padding.large * 2
            implicitHeight: tipText.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.full
            color: Glass.enabled ? Glass.sheet : Colours.palette.m3surfaceContainerHigh
            opacity: showing ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    duration: 120
                }
            }
            Behavior on x {
                enabled: tip.showing
                Anim {
                    duration: 160
                }
            }

            Timer {
                id: tipTimer

                interval: 350
                onTriggered: tip.showing = true
            }

            StyledText {
                id: tipText

                anchors.centerIn: parent
                text: panel.tipLabel
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }
        }

        StyledRect {
            id: panel

            readonly property real gap: 2
            readonly property real pad: 6
            readonly property real iconPt: Tokens.font.icon.large.pointSize * 1.25
            readonly property real growth: (iconPt - Tokens.font.icon.large.pointSize) * 4 / 3
            readonly property real tileH: 56 + growth
            readonly property real lift: 56
            property string tipLabel
            property real tipX
            readonly property int slots: Math.max(root.count, 1)
            readonly property real tileW: Math.max(40, Math.min(68 + growth, Math.floor(((win.screen?.width ?? 1920) * 0.9 - pad * 2 - (slots - 1) * gap) / slots)))
            readonly property real fullWidth: slots * tileW + (slots - 1) * gap + pad * 2
            readonly property real fullHeight: tileH + pad * 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: win.shown ? 0 : -(fullHeight + win.margins.bottom + 8)
            opacity: win.shown ? 1 : 0

            Behavior on anchors.bottomMargin {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on opacity {
                Anim {}
            }

            color: "transparent"
            radius: fullHeight / 2
            implicitWidth: fullWidth
            implicitHeight: fullHeight

            Behavior on implicitWidth {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            HoverHandler {
                id: hover
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: mouse => root.openPopup("dock", -1, panel)
            }

            ListView {
                id: row

                anchors.horizontalCenter: parent.horizontalCenter
                y: panel.pad
                width: panel.fullWidth - panel.pad * 2
                height: panel.tileH
                orientation: ListView.Horizontal
                spacing: panel.gap
                interactive: false
                model: root.apps

                move: Transition {
                    Anim {
                        property: "x"
                        type: Anim.DefaultSpatial
                    }
                }

                moveDisplaced: Transition {
                    Anim {
                        property: "x"
                        type: Anim.DefaultSpatial
                    }
                }

                addDisplaced: moveDisplaced
                removeDisplaced: moveDisplaced
                add: Transition {
                    Anim {
                        property: "scale"
                        from: 0.4
                        to: 1
                        type: Anim.DefaultSpatial
                    }
                }

                delegate: Tile {}
            }

            Item {
                id: dragLayer

                anchors.fill: row
                z: 10
            }
        }
    }

    component Tile: Item {
        id: slot

        required property int index
        required property string json
        readonly property var app: JSON.parse(json)
        readonly property var entry: app?.id ? DesktopEntries.heuristicLookup(app.id) : null
        readonly property var windows: root.windowsOf(app)
        readonly property bool running: windows.length > 0
        readonly property bool focused: windows.some(w => w.id === CosmicWindows.activeId)
        readonly property string label: app?.name ?? entry?.name ?? app?.id ?? ""
        readonly property string symbol: app?.symbol || root.symbolFor(`${app?.name ?? ""} ${app?.match ?? ""} ${app?.id ?? ""} ${entry?.name ?? ""}`) || Icons.getAppCategoryIcon(app?.id ?? "", "apps")

        readonly property string iconSource: {
            const i = app?.icon || entry?.icon || app?.id || "";
            if (i.startsWith("/"))
                return `file://${i}`;
            if (i.includes("/"))
                return `file://${Quickshell.shellPath(`../${i}`)}`;
            return Quickshell.iconPath(i, true) || `file://${Paths.home}/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/${i}.png` || Quickshell.iconPath("application-x-executable");
        }

        width: panel.tileW
        height: panel.tileH

        MouseArea {
            id: area

            property bool held
            property bool dragged
            property real pressX
            property real grabOffset

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: held ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse) {
                    panel.tipLabel = slot.label;
                    panel.tipX = slot.mapToItem(win.contentItem, slot.width / 2, 0).x;
                } else if (panel.tipLabel === slot.label) {
                    panel.tipLabel = "";
                }
            }

            onPressed: mouse => {
                pressX = mapToItem(dragLayer, mouse.x, 0).x;
                grabOffset = mouse.x;
                dragged = false;
            }
            onPositionChanged: mouse => {
                if (!(pressedButtons & Qt.LeftButton))
                    return;
                const px = mapToItem(dragLayer, mouse.x, 0).x;
                if (!held && Math.abs(px - pressX) > 8) {
                    held = true;
                    dragged = true;
                    root.dragging = true;
                }
                if (held) {
                    content.x = Math.max(-panel.tileW / 2, Math.min(dragLayer.width - panel.tileW / 2, px - grabOffset));
                    const to = Math.max(0, Math.min(root.count - 1, Math.floor((content.x + panel.tileW / 2) / (panel.tileW + panel.gap))));
                    if (to !== slot.index)
                        root.apps.move(slot.index, to, 1);
                }
            }
            onReleased: mouse => {
                if (held) {
                    held = false;
                    root.dragging = false;
                    root.save();
                }
            }
            onCanceled: {
                held = false;
                root.dragging = false;
            }
            onClicked: mouse => {
                if (dragged)
                    return;
                if (mouse.button === Qt.RightButton)
                    root.openPopup("app", slot.index, slot);
                else
                    root.open(slot.app);
            }
        }

        Item {
            id: content

            width: panel.tileW
            height: panel.tileH

            states: State {
                when: area.held

                ParentChange {
                    target: content
                    parent: dragLayer
                }
            }

            transitions: Transition {
                ParentAnimation {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            ClippingRectangle {
                id: icon

                readonly property real base: panel.tileH - 6
                readonly property bool badge: !!slot.app?.bg
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 - lift
                property real lift: area.held ? 10 : area.pressed ? 0 : area.containsMouse ? 8 : 0
                width: base
                height: base
                radius: badge ? base / 2 : 0
                color: badge ? slot.app.bg : "transparent"
                transformOrigin: Item.Bottom
                scale: area.held ? 1.25 : area.pressed ? 0.92 : area.containsMouse ? 1.3 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 2
                    }
                }
                Behavior on lift {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: icon.base * (1 - 2 * (slot.app?.inset ?? 0))
                    source: slot.iconSource
                    asynchronous: true
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                height: 4
                width: slot.focused ? 14 : 4
                radius: 2
                color: Colours.palette.m3onSurface
                opacity: slot.running ? (slot.focused ? 0.95 : 0.6) : 0

                Behavior on width {
                    Anim {
                        duration: 160
                    }
                }
                Behavior on opacity {
                    Anim {
                        duration: 160
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // 2. Desktop Dashboard Widgets Window (Underlapped Modular Cards)
    // ─────────────────────────────────────────────────────────────────────────────
    StyledWindow {
        id: dashboardWin

        screen: Quickshell.screens[0]
        name: "dock-dashboard"

        readonly property bool isSearchActive: !!dashboard.commandBarCard?.searchFocused

        WlrLayershell.layer: (!DashboardState.isLocked || isSearchActive) ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: isSearchActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080

        readonly property bool hasWindowsOnWorkspace: CosmicWindows.windows.some(w => w.workspace_active && !w.minimized)
        readonly property bool shown: !hasWindowsOnWorkspace && !CosmicWindows.fullscreen

        Region {
            id: emptyRegion
        }

        Region {
            id: fullRegion
            x: 0
            y: 0
            width: dashboardWin.width
            height: dashboardWin.height
        }

        mask: !dashboardWin.shown ? emptyRegion : (!DashboardState.isLocked || isSearchActive ? fullRegion : cardMasks)

        Region {
            id: cardMasks

            Region { item: dashboard.commandBarCard?.visible ? dashboard.commandBarCard.surface : null }
            Region { item: dashboard.systemMonitorCard?.visible ? dashboard.systemMonitorCard.surface : null }
            Region { item: dashboard.notifCard?.visible ? dashboard.notifCard.surface : null }
            Region { item: dashboard.mailCard?.visible ? dashboard.mailCard.surface : null }
        }

        // Tap outside when search is active to unfocus
        MouseArea {
            id: searchOutsideDismiss
            anchors.fill: parent
            enabled: dashboardWin.isSearchActive
            z: 0
            onClicked: {
                if (dashboard.commandBarCard) {
                    dashboard.commandBarCard.unfocusSearch();
                }
            }
        }

        DockDashboard {
            id: dashboard
            z: 1

            opacity: dashboardWin.shown ? 1.0 : 0.0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    duration: 250
                }
            }
        }
    }
}
