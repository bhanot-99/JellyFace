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

// JellyFace Modular Desktop Widget Ecosystem:
// Independent floating windows/cards on WlrLayer.Bottom with freeform drag/drop,
// corner resizing, snap-to-grid, canvas persistence, and global edit/lock mode.
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
            popupAnchor = Qt.point((s.width - win.width) / 2 + p.x, (s.height - win.height) / 2 + p.y);
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

        // Underlapped desktop surface when locked, elevated to Top in Edit Mode for fluid repositioning
        WlrLayershell.layer: !DashboardState.isLocked ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080

        // Visible only when workspace is clean (no unminimized windows on active workspace and no fullscreen)
        readonly property bool hasWindowsOnWorkspace: CosmicWindows.windows.some(w => w.workspace_active && !w.minimized)
        readonly property bool shown: !hasWindowsOnWorkspace && !CosmicWindows.fullscreen

        Region {
            id: emptyRegion
        }

        Region {
            id: fullRegion
            x: 0
            y: 0
            width: win.width
            height: win.height
        }

        // Non-card canvas space is completely click-through to wallpaper/desktop when locked.
        // In Edit Mode, fullRegion allows smooth dragging and resizing across the display.
        // When hidden (apps active on workspace), emptyRegion ensures 100% click-through.
        mask: !win.shown ? emptyRegion : (!DashboardState.isLocked ? fullRegion : cardMasks)

        Region {
            id: cardMasks

            Region { item: dashboard.commandBarCard?.surface }
            Region { item: dashboard.workDevCard?.surface }
            Region { item: dashboard.aiWebCard?.surface }
            Region { item: dashboard.mediaToolsCard?.surface }
            Region { item: dashboard.profileCard?.surface }
            Region { item: dashboard.systemMonitorCard?.surface }
            Region { item: dashboard.notifCard?.surface }
            Region { item: dashboard.mailCard?.surface }
        }

        BackgroundEffect.blurRegion: (Glass.enabled && win.shown) ? dockBlur : null

        Region {
            id: dockBlur

            GlassRegion { pane: dashboard.commandBarCard?.surface }
            GlassRegion { pane: dashboard.workDevCard?.surface }
            GlassRegion { pane: dashboard.aiWebCard?.surface }
            GlassRegion { pane: dashboard.mediaToolsCard?.surface }
            GlassRegion { pane: dashboard.profileCard?.surface }
            GlassRegion { pane: dashboard.systemMonitorCard?.surface }
            GlassRegion { pane: dashboard.notifCard?.surface }
            GlassRegion { pane: dashboard.mailCard?.surface }
        }

        DockDashboard {
            id: dashboard

            dock: root
            opacity: win.shown ? 1.0 : 0.0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    duration: 250
                }
            }
        }
    }
}
