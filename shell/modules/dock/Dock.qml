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
// Hovering magnifies the icon under the cursor (and a little its neighbours). Menus and dialogs: DockPopups.qml.
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

        GlassRegion {
            id: dockBlur

            pane: panel
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

        StyledRect {
            id: panel

            readonly property real gap: Tokens.spacing.medium
            readonly property real pad: Tokens.padding.large
            readonly property real lift: 10                // headroom above the row for magnified icons
            readonly property int slots: Math.max(root.count, 1)
            // 64px tiles, shrunk when there are so many apps that the row would not fit on the screen
            readonly property real tile: Math.max(32, Math.min(64, Math.floor(((win.screen?.width ?? 1920) * 0.9 - pad * 2 - (slots - 1) * gap) / slots)))
            readonly property real fullWidth: slots * tile + (slots - 1) * gap + pad * 2
            readonly property real fullHeight: tile + pad * 2
            property real hoverX: -1000                     // pointer x in the row, for magnification

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

            color: Colours.tPalette.m3surface
            radius: Tokens.rounding.extraLarge
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
            // the pointer's position along the row, for magnification
            HoverHandler {
                id: hover

                onHoveredChanged: if (!hovered) panel.hoverX = -1000
                onPointChanged: panel.hoverX = row.mapFromItem(panel, point.position.x, 0).x
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
                height: panel.tile
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
        readonly property string iconSource: app?.icon?.includes("/") ? `file://${Quickshell.shellPath("../" + app.icon)}` : (app?.icon || entry?.icon) ? Quickshell.iconPath(app.icon || entry.icon, "application-x-executable") : ""

        // magnification: 1 at a distance, up to 1.32 right under the pointer, a smooth (cosine) falloff over 1.6 tiles
        readonly property real near: {
            if (root.dragging || root.popup !== "")
                return 0;
            const d = Math.abs(panel.hoverX - (x + width / 2)) / (panel.tile * 1.6);
            return d >= 1 ? 0 : (Math.cos(d * Math.PI) + 1) / 2;
        }

        width: panel.tile
        height: panel.tile

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
                    content.x = Math.max(-panel.tile / 2, Math.min(dragLayer.width - panel.tile / 2, px - grabOffset));
                    // reorder as soon as the dragged tile's centre passes a neighbour's slot
                    const to = Math.max(0, Math.min(root.count - 1, Math.floor((content.x + panel.tile / 2) / (panel.tile + panel.gap))));
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

            width: panel.tile
            height: panel.tile

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

            // hover / pressed / dragged background
            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainer
                scale: area.held ? 1.08 : 1 + slot.near * 0.06

                Behavior on scale {
                    Anim {
                        duration: 140
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colours.palette.m3onSurface
                    opacity: area.held ? 0.12 : area.pressed ? 0.1 : area.containsMouse ? 0.06 : 0

                    Behavior on opacity {
                        Anim {
                            duration: 120
                        }
                    }
                }
            }

            Item {
                id: iconBox

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: panel.tile * 0.6
                height: width
                // lift and grow towards the pointer
                anchors.verticalCenterOffset: -slot.near * panel.lift * 0.7 - (area.held ? 4 : 0)
                scale: area.held ? 1.18 : area.pressed ? 0.92 : 1 + slot.near * 0.32

                Behavior on scale {
                    Anim {
                        duration: 140
                    }
                }
                Behavior on anchors.verticalCenterOffset {
                    Anim {
                        duration: 140
                    }
                }

                IconImage {
                    anchors.fill: parent
                    visible: slot.iconSource !== ""
                    source: slot.iconSource
                    asynchronous: true
                }

                // a web app without an icon: its first letter on a tinted disc
                StyledRect {
                    anchors.fill: parent
                    visible: slot.iconSource === ""
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primaryContainer

                    StyledText {
                        anchors.centerIn: parent
                        text: slot.label.charAt(0).toUpperCase()
                        color: Colours.palette.m3onPrimaryContainer
                        font.pointSize: panel.tile * 0.24
                        font.weight: Font.Bold
                    }
                }
            }

            // running indicator: a dot under the icon, a wider pill for the focused app
            StyledRect {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tokens.padding.small / 2
                implicitWidth: slot.focused ? 14 : 5
                implicitHeight: 5
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
                opacity: slot.running && !area.held ? 1 : 0

                Behavior on implicitWidth {
                    Anim {}
                }
                Behavior on opacity {
                    Anim {}
                }
            }
        }
    }
}
