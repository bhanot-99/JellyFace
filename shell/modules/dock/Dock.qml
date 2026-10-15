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

// JellyFace Desktop Dashboard Widget: transforms the bottom dock into a full frosted-glass dashboard widget
// with search bar connected to Brave, 3 app category cards, system resource gauges (CPU/RAM/Disk),
// live network sparkline, disk analyzer launcher, active window activity, profile card, live notifications,
// and primary emails feed.
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

    // The windows that belong to an app.
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

    StyledWindow {
        id: win

        screen: Quickshell.screens[0]
        name: "dock-dashboard"
        WlrLayershell.layer: JellyPanel.open ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.bottom: true
        margins.bottom: 24

        readonly property real dockW: Math.min(1080, Math.floor((screen?.width ?? 1920) * 0.92))
        readonly property real dockH: 660

        implicitWidth: dockW
        implicitHeight: dockH

        mask: Region {
            item: dashboard
        }

        BackgroundEffect.blurRegion: Glass.enabled ? dockBlur : null

        Region {
            id: dockBlur

            GlassRegion {
                pane: dashboard
            }
        }

        // Logical geometry of the dashboard widget
        readonly property rect dockRect: Qt.rect(((screen?.width ?? 1920) - win.implicitWidth) / 2, (screen?.height ?? 1080) - margins.bottom - win.implicitHeight, win.implicitWidth, win.implicitHeight)

        // Windows covering the dashboard area on current active workspace
        readonly property bool covered: CosmicWindows.fullscreen || CosmicWindows.windows.some(w => w.workspace_active && !w.minimized && w.w > 0 && w.x < dockRect.x + dockRect.width && w.x + w.w > dockRect.x && w.y < dockRect.y + dockRect.height && w.y + w.h > dockRect.y)

        property bool manualHidden: false
        readonly property bool wanted: !manualHidden && (JellyPanel.open || !covered || hover.hovered || DockReveal.edge || root.popup !== "")
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

        Connections {
            function onEdgeChanged(): void {
                if (DockReveal.edge) {
                    win.manualHidden = false;
                    win.shown = true;
                }
            }

            target: DockReveal
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

        DockDashboard {
            id: dashboard

            dock: root
            width: win.dockW
            height: win.dockH

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: win.shown ? 0 : -(win.dockH + win.margins.bottom + 20)
            opacity: win.shown ? 1 : 0

            Behavior on anchors.bottomMargin {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on opacity {
                Anim {}
            }

            HoverHandler {
                id: hover
            }

            onRequestHide: {
                win.manualHidden = true;
                win.shown = false;
            }
        }
    }
}
