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

// JellyFace dock: a single row of apps at the bottom centre of the screen, above windows. It slides out of sight while a
// window on the current workspace overlaps it (or anything is fullscreen) and comes back when nothing does, when the
// cursor is pushed to the bottom edge under it, or while JellyPanel is open. Apps come from ~/.config/jellyface/dock.json.
//   drag a tile sideways to reorder it | right-click a tile for its menu | right-click the open dock to add apps
// Each app is a monochrome symbol on a pill whose shade shows its state: solid white = the app in front, faint frost =
// running, lighter frost = under the pointer (whose name then shows above it). Menus and dialogs: DockPopups.qml.
Scope {
    id: root

    // one entry per tile: { json } (the app object as JSON text; a ListModel cannot hold nested objects)
    property ListModel apps: ListModel {}
    property var extra: ({})          // any other keys in dock.json, kept as they are
    property string lastWritten
    readonly property int count: apps.count

    // what is open: "" | "app" (a tile's menu) | "dock" (the dock's menu) | "addApp" | "addWeb"
    property string popup
    property int popupIndex: -1
    property point popupAnchor        // screen position the menu points at (tile centre, top edge)
    property bool dragging

    // Monochrome Material Symbols for the dock, matched on an app's name, web address or desktop id (lower case).
    // First match wins, so specific names come before generic words. Set "symbol" on an app in dock.json to choose.
    readonly property var symbols: [
        [["youtube"], "smart_display"],
        [["pinterest"], "push_pin"],
        [["chatgpt", "openai"], "smart_toy"],
        [["claude"], "asterisk"],
        [["gemini"], "auto_awesome"],
        [["github.com", "gitlab.com"], "commit"], // not plain "github": many Flatpak ids are io.github.*
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

    // The windows that belong to an app. An app with a "match" (the web apps) owns every window whose class
    // contains it; any other app owns the windows whose class is its desktop id or its StartupWMClass.
    function windowsOf(app: var): var {
        if (!app)
            return [];
        const entry = app.id ? DesktopEntries.heuristicLookup(app.id) : null;
        const ids = [app.id, entry?.startupClass, entry?.id].filter(x => x).map(x => x.toLowerCase().replace(/\.desktop$/, ""));
        if (app.id)
            ids.push(app.id.split(".").pop().toLowerCase()); // Flatpak/Electron apps often report just "obsidian"
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

    // Running app: focus its window (a further click cycles through its windows). Otherwise launch it.
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
            return; // our own save coming back through the file watcher: nothing changed
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

    StyledWindow {
        id: win

        screen: Quickshell.screens[0]
        name: "dock"
        // above windows (it gets out of their way by hiding); above JellyPanel too while that is open, as on macOS
        WlrLayershell.layer: JellyPanel.open ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        // anchored to the bottom edge only: the compositor centres the window horizontally
        anchors.bottom: true
        // read through contentItem: the window itself is not an Item, so plain Tokens/Config here had no screen (warnings)
        margins.bottom: Math.max(contentItem.Tokens.padding.small, contentItem.Config.border.thickness) + contentItem.Tokens.padding.extraLargeIncreased

        implicitWidth: panel.fullWidth
        implicitHeight: panel.fullHeight + panel.lift
        // only the dock itself takes the pointer; the rest of this (transparent) window is click-through
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

        // where the dock sits on screen when shown, in the same logical pixels COSMIC reports window geometry in
        readonly property rect dockRect: Qt.rect(((screen?.width ?? 1920) - panel.fullWidth) / 2, (screen?.height ?? 1080) - margins.bottom - panel.fullHeight, panel.fullWidth, panel.fullHeight)
        // a visible window on this workspace overlaps the dock, or something is fullscreen
        readonly property bool covered: CosmicWindows.fullscreen || CosmicWindows.windows.some(w => w.workspace_active && !w.minimized && w.w > 0 && w.x < dockRect.x + dockRect.width && w.x + w.w > dockRect.x && w.y < dockRect.y + dockRect.height && w.y + w.h > dockRect.y)
        readonly property bool wanted: JellyPanel.open || !covered || hover.hovered || DockReveal.edge || root.popup !== "" || root.dragging
        property bool shown: true

        // show at once; hide after a moment, so moving from the edge up into the dock never makes it flicker
        Component.onCompleted: if (!wanted) hideTimer.restart() // already covered when the shell starts
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

        // the hovered app's name in a small glass pill above it, after a short pause (no flashing while sweeping across)
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

            // a glass capsule of pill-shaped slots, each holding a monochrome symbol
            readonly property real gap: 2
            readonly property real pad: 6                   // the capsule's rim around the pills
            // symbols 25% above the theme's large icon size; the pills grow by just as much, so the space around each
            // symbol stays the same (font points -> pixels: x 4/3)
            readonly property real iconPt: Tokens.font.icon.large.pointSize * 1.25
            readonly property real growth: (iconPt - Tokens.font.icon.large.pointSize) * 4 / 3
            readonly property real tileH: 56 + growth
            readonly property real lift: 56                 // headroom above the dock for the name tooltip
            // the app under the pointer, for the name tooltip
            property string tipLabel
            property real tipX
            readonly property int slots: Math.max(root.count, 1)
            // 60px-wide pills (plus the growth), narrower when there are so many apps that the row would not fit on the screen
            readonly property real tileW: Math.max(40, Math.min(68 + growth, Math.floor(((win.screen?.width ?? 1920) * 0.9 - pad * 2 - (slots - 1) * gap) / slots)))
            readonly property real fullWidth: slots * tileW + (slots - 1) * gap + pad * 2
            readonly property real fullHeight: tileH + pad * 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            // hidden: slid down out of the window (so it takes no clicks and no blur), faded on the way
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
            // the pointer is over the dock (keeps it shown while auto-hide would hide it)
            HoverHandler {
                id: hover
            }

            // right-click on the dock (not on a tile): add apps
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

                // the other tiles slide out of the way while one is dragged
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

            // while dragged, a tile is lifted into this layer so it can move freely over the row
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
        // the app's monochrome symbol: "symbol" in dock.json, else a match on its name or id, else its category
        readonly property string symbol: app?.symbol || root.symbolFor(`${app?.name ?? ""} ${app?.match ?? ""} ${app?.id ?? ""} ${entry?.name ?? ""}`) || Icons.getAppCategoryIcon(app?.id ?? "", "apps")

        // "icon" in dock.json: an absolute path, a path relative to the JellyFace folder, or a theme icon name;
        // otherwise the desktop entry's icon
        readonly property string iconSource: {
            const i = app?.icon || entry?.icon || app?.id || "";
            if (i.startsWith("/"))
                return `file://${i}`;
            if (i.includes("/"))
                return `file://${Quickshell.shellPath(`../${i}`)}`;
            // theme icon, else the user's Flatpak exports (not on the container's icon path), else a generic one
            return Quickshell.iconPath(i, true) || `file://${Paths.home}/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/${i}.png` || Quickshell.iconPath("application-x-executable");
        }

        width: panel.tileW
        height: panel.tileH

        MouseArea {
            id: area

            property bool held
            property bool dragged             // this press became a drag: its release is not a click
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
                    // reorder as soon as the dragged tile's centre passes a neighbour's slot
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

            // glide into the (new) slot when the drag ends, instead of jumping
            transitions: Transition {
                ParentAnimation {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // the app's real icon: no pill behind it. Under the pointer it springs up and grows; pressed it squashes;
            // dragged it is lifted a little more. Running apps get a dot underneath, the focused one a longer dot.
            IconImage {
                id: icon

                readonly property real base: panel.tileH - 6
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 - lift
                property real lift: area.held ? 10 : area.pressed ? 0 : area.containsMouse ? 8 : 0
                implicitSize: base
                source: slot.iconSource
                asynchronous: true
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
}
