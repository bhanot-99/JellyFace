pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.quill
import qs.quill.components

// The command bar (Super+Space, or Super): one search for everything.
//   maths "24*7" and units "5 km in mi" (Enter copies the result) · open windows · apps · Quill's settings and
//   Control Center pages · actions (lock, sleep, focus, dark mode...) · files in your home folder
// With nothing typed it lists the open windows and the dock's apps. ↑↓ select, Enter runs, Esc clears then closes.
Surface {
    id: root

    name: "command"
    anchors.fill: parent

    property string query: field.text.trim()
    property int current: 0
    property var files: []

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    onActiveChanged: {
        if (active) {
            field.text = QuillState.commandText;
            QuillState.commandText = "";
            current = 0;
            QuillApps.refreshHost();
            field.input.forceActiveFocus();
        }
    }
    onQueryChanged: {
        current = 0;
        files = [];
        if (query.length >= 3 && !Calc.evaluate(query) && !Calc.convert(query))
            fileTimer.restart();
        else
            fileTimer.stop();
    }

    // ── what can be found ──
    function score(text: string, q: string): real {
        const t = (text ?? "").toLowerCase();
        if (!t)
            return 0;
        if (t === q)
            return 4;
        if (t.startsWith(q))
            return 3;
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 2;
        if (t.includes(q))
            return 1;
        // letters in order ("tml" finds "terminal")
        let i = 0;
        for (const ch of t)
            if (ch === q[i])
                i++;
        return i === q.length ? 0.4 : 0;
    }

    readonly property var places: [
        {title: "Appearance", sub: "Theme, accent, wallpaper, glass, dock", icon: "palette", keys: "appearance theme look style personal", run: () => QuillState.show("appearance")},
        {title: "Theme", sub: "Light, dark or auto", icon: "contrast", keys: "theme dark light mode night", run: () => root.appearance("theme")},
        {title: "Accent color", sub: "Appearance", icon: "colors", keys: "accent colour color", run: () => root.appearance("accent")},
        {title: "Wallpaper", sub: "Appearance", icon: "wallpaper", keys: "wallpaper background desktop", run: () => root.appearance("wallpaper")},
        {title: "Glass", sub: "Transparency and frost", icon: "blur_on", keys: "glass blur transparency frost", run: () => root.appearance("glass")},
        {title: "Dock & side bar", sub: "Appearance", icon: "dock_to_bottom", keys: "dock bar side panel hide", run: () => root.appearance("dock")},
        {title: "Keyboard shortcuts", sub: "Every Quill shortcut", icon: "keyboard", keys: "keyboard shortcuts keys hotkeys", run: () => QuillState.show("keys")},
        {title: "Wi-Fi", sub: "Control Center", icon: "wifi", keys: "wifi wi-fi network internet wireless", run: () => root.cc("wifi")},
        {title: "Bluetooth", sub: "Control Center", icon: "bluetooth", keys: "bluetooth devices headphones pair", run: () => root.cc("bluetooth")},
        {title: "Sound", sub: "Control Center", icon: "volume_up", keys: "sound audio volume output speaker microphone", run: () => root.cc("sound")},
        {title: "Battery", sub: "Power profile", icon: "battery_full", keys: "battery power profile performance saver", run: () => root.cc("battery")},
        {title: "Focus", sub: "Do Not Disturb and Deep Focus", icon: "bedtime", keys: "focus dnd do not disturb quiet", run: () => root.cc("focus")},
        {title: "Notifications", sub: "Control Center", icon: "notifications", keys: "notifications", run: () => root.cc("notifications")},
        {title: "Today", sub: "Calendar, weather, media", icon: "calendar_today", keys: "today calendar date weather agenda events", run: () => QuillState.show("today")},
        {title: "Desks", sub: "Every desk and its windows", icon: "view_carousel", keys: "desks workspaces overview", run: () => QuillState.show("desks")},
        {title: "Window hints", sub: "Jump to a window by its letter", icon: "keyboard_command_key", keys: "hints windows jump", run: () => QuillState.show("hints")},
        {title: "Clipboard", sub: "Everything you copied", icon: "content_paste", keys: "clipboard copy paste history", run: () => QuillState.show("clipboard")},
        {title: "Style gallery", sub: "Every Quill component", icon: "auto_awesome", keys: "gallery style design", run: () => QuillState.show("gallery")}
    ]

    readonly property var actions: [
        {title: "Lock", icon: "lock", keys: "lock screen", run: () => Session.lock()},
        {title: "Sleep", icon: "bedtime", keys: "sleep suspend", run: () => Session.sleep()},
        {title: "Restart", icon: "restart_alt", keys: "restart reboot", run: () => QuillState.show("session")},
        {title: "Shut down", icon: "power_settings_new", keys: "shut down shutdown power off poweroff", run: () => QuillState.show("session")},
        {title: "Log out", icon: "logout", keys: "log out logout sign out", run: () => QuillState.show("session")},
        {title: DeepFocus.active ? "Stop Deep Focus" : "Start Deep Focus", icon: "self_improvement", keys: "deep focus timer pomodoro work", run: () => DeepFocus.active ? DeepFocus.stop() : DeepFocus.start(0)},
        {title: Notifs.dnd ? "Turn off Do Not Disturb" : "Turn on Do Not Disturb", icon: "do_not_disturb_on", keys: "do not disturb dnd quiet silence", run: () => Notifs.dnd = !Notifs.dnd},
        {title: Theme.dark ? "Light mode" : "Dark mode", icon: Theme.dark ? "light_mode" : "dark_mode", keys: "dark light mode theme night", run: () => QuillConfig.set("theme", Theme.dark ? "light" : "dark")},
        {title: IdleInhibitor.enabled ? "Stop keeping awake" : "Keep awake", icon: "coffee", keys: "keep awake caffeine inhibit idle", run: () => IdleInhibitor.enabled = !IdleInhibitor.enabled},
        {title: "Screenshot", icon: "screenshot_region", keys: "screenshot screen capture", run: () => Quickshell.execDetached(["distrobox-host-exec", "cosmic-screenshot"])},
        {title: "Record screen", icon: "videocam", keys: "record screen recording video", run: () => Recorder.openKooha()},
        {title: "Switch to Classic", sub: "JellyFace's original interface", icon: "swap_horiz", keys: "classic old original interface switch ui", run: () => Quickshell.execDetached(["distrobox-host-exec", Quickshell.shellPath("../bin/jellyface"), "ui", "classic"])}
    ]

    function appearance(page: string): void {
        QuillState.appearancePage = page;
        QuillState.show("appearance");
    }

    function cc(page: string): void {
        QuillState.show("cc");
        QuillState.ccPage = page;
    }

    function windowRow(w: var): var {
        const current = w.id === CosmicWindows.activeId;
        return {
            iconSource: QuillApps.iconForClass(w.app_id),
            icon: "web_asset",
            title: w.title || QuillApps.nameForClass(w.app_id),
            sub: w.title ? QuillApps.nameForClass(w.app_id) : "",
            trailing: current ? "Current window" : "Window",
            run: () => CosmicWindows.activate(w.id)
        };
    }

    function appRow(a: var): var {
        return {
            iconSource: QuillApps.iconOf({id: a.id}, a),
            icon: "apps",
            title: a.name,
            sub: a.genericName ?? "",
            trailing: "App",
            run: () => QuillApps.launchEntry(a)
        };
    }

    readonly property var results: {
        const q = query.toLowerCase();
        const out = [];
        if (!q) {
            for (const w of [...CosmicWindows.windows].sort((a, b) => (b.id === CosmicWindows.activeId) - (a.id === CosmicWindows.activeId)))
                out.push(windowRow(w));
            for (const a of QuillApps.dock.filter(a => a.id).slice(0, 8)) {
                const e = QuillApps.entryOf(a);
                if (e && !CosmicWindows.windows.some(w => QuillApps.classesOf(a, e).includes((w.app_id ?? "").toLowerCase())))
                    out.push(appRow(e));
            }
            return out;
        }
        const maths = Calc.evaluate(q);
        if (maths)
            out.push({big: true, icon: "calculate", title: `= ${maths}`, sub: "Calculator", trailing: "Enter to copy", run: () => Quickshell.clipboardText = maths});
        const conv = Calc.convert(q);
        if (conv)
            out.push({big: true, icon: "straighten", title: conv.value, sub: `Units · ${conv.detail}`, trailing: "Enter to copy", run: () => Quickshell.clipboardText = conv.raw});

        const ranked = [];
        for (const w of CosmicWindows.windows) {
            const s = Math.max(score(w.title, q), score(QuillApps.nameForClass(w.app_id), q));
            if (s > 0)
                ranked.push([s + 0.6, windowRow(w)]);
        }
        for (const a of QuillApps.all) {
            const s = Math.max(score(a.name, q), score(a.genericName, q) * 0.7, (a.keywords ?? []).some(k => k.toLowerCase().startsWith(q)) ? 0.8 : 0);
            if (s > 0)
                ranked.push([s, appRow(a)]);
        }
        for (const p of places) {
            const s = Math.max(score(p.title, q), p.keys.split(" ").some(k => k.startsWith(q)) ? 1.5 : 0);
            if (s > 0)
                ranked.push([s * 0.9, {icon: p.icon, title: p.title, sub: p.sub, trailing: "Setting", run: p.run}]);
        }
        for (const a of actions) {
            const s = Math.max(score(a.title, q), a.keys.split(" ").some(k => k.startsWith(q)) ? 1.5 : 0);
            if (s > 0)
                ranked.push([s * 0.85, {icon: a.icon, title: a.title, sub: a.sub ?? "", trailing: "Action", run: a.run}]);
        }
        ranked.sort((a, b) => b[0] - a[0]);
        for (const r of ranked.slice(0, 12))
            out.push(r[1]);
        for (const f of files)
            out.push({icon: f.dir ? "folder" : "draft", title: f.name, sub: f.where, trailing: "File", run: () => Quickshell.execDetached(["distrobox-host-exec", "xdg-open", f.path])});
        return out;
    }

    function run(i: int): void {
        const r = results[i];
        if (!r)
            return;
        QuillState.close();
        r.run();
    }

    // ── files ──
    Timer {
        id: fileTimer

        interval: 220
        onTriggered: {
            findProc.running = false;
            findProc.command = ["sh", "-c", "find \"$HOME\" -maxdepth 4 \\( -name '.*' -o -name node_modules -o -name target -o -name __pycache__ \\) -prune -o -iname \"*$1*\" -printf '%y\\t%p\\n' 2>/dev/null | head -n 6", "find", root.query];
            findProc.running = true;
        }
    }

    Process {
        id: findProc

        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME");
                root.files = text.split("\n").filter(l => l).map(l => {
                    const [type, path] = l.split("\t");
                    const parts = path.split("/");
                    return {
                        dir: type === "d",
                        path: path,
                        name: parts.pop(),
                        where: parts.join("/").replace(home, "~")
                    };
                });
            }
        }
    }

    // ── the bar ──
    Glass {
        id: sheet

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.2)
        width: 660
        height: field.height + (list.count > 0 ? listFrame.height + 10 : 0) + footer.height + 10
        color: Theme.sheet
        scale: 0.97 + 0.03 * root.progress

        Behavior on height {
            Anim { duration: Theme.normal }
        }

        MouseArea {
            anchors.fill: parent
        }

        SearchField {
            id: field

            width: parent.width
            height: 60
            size: Theme.heading + 2
            placeholder: "Search apps, windows, settings, or type 24*7"
            onAccepted: root.run(root.current)
            onEscaped: field.text ? field.text = "" : QuillState.close()
            onNavigate: d => {
                root.current = Math.max(0, Math.min(root.results.length - 1, root.current + d));
                list.positionViewAtIndex(root.current, ListView.Contain);
            }
        }

        Rectangle {
            visible: list.count > 0
            anchors.top: field.bottom
            x: 16
            width: parent.width - 32
            height: 1
            color: Theme.divider
        }

        Item {
            id: listFrame

            anchors.top: field.bottom
            anchors.topMargin: 6
            x: 8
            width: parent.width - 16
            height: Math.min(list.contentHeight, 420)

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                model: root.results
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: ListRow {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    rowHeight: modelData.big ? 64 : 42
                    titleSize: modelData.big ? Theme.title + 4 : Theme.body
                    icon: modelData.iconSource ? "" : modelData.icon
                    iconSource: modelData.iconSource ?? ""
                    title: modelData.title
                    subtitle: modelData.sub ?? ""
                    trailing: modelData.trailing ?? ""
                    current: root.current === index
                    onClicked: root.run(index)
                    onHoveredChanged: if (hovered) root.current = index
                }
            }
        }

        Row {
            id: footer

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            height: 24
            spacing: 6

            Keycap { key: "↑↓" }
            Label { text: "select"; size: Theme.caption + 1; muted: true; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 8; height: 1 }
            Keycap { key: "↵" }
            Label { text: "open"; size: Theme.caption + 1; muted: true; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 8; height: 1 }
            Keycap { key: "esc" }
            Label { text: "close"; size: Theme.caption + 1; muted: true; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
