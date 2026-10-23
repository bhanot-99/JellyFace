pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Apps for Quill: the dock's list (the same ~/.config/jellyface/dock.json as Classic, so both docks show the same
// apps), their icons and windows, and launching on the host (the shell runs in a container whose own apps don't
// exist on the desktop). Matching follows Classic's dock: a window belongs to an app when its class is the app's
// desktop id (or its last part, or the entry's StartupWMClass); web apps match a substring instead.
Singleton {
    id: root

    property var dock: []
    property var extra: ({})
    property string lastWritten

    // desktop ids installed on the host (the container's own apps are left out of search)
    property var hostIds: null

    function entryOf(app: var): var {
        // read the app list so a binding that calls this looks again once the entries are scanned: at startup the
        // lookup finds nothing, and the dock's names fell back to raw app ids for good
        void DesktopEntries.applications.values;
        return app?.id ? DesktopEntries.heuristicLookup(app.id) : null;
    }

    function iconOf(app: var, entry: var): string {
        const i = app?.icon || entry?.icon || app?.id || "";
        if (i.startsWith("/"))
            return `file://${i}`;
        if (i.includes("/"))
            return `file://${Quickshell.shellPath(`../${i}`)}`;
        const themed = Quickshell.iconPath(i, true);
        if (themed)
            return themed;
        // an installed app the theme can't see is usually a user flatpak; a window with no app at all (a web app that
        // shipped no icon) gets the generic one instead of a path that doesn't exist
        if (entry || app?.icon)
            return `file://${Paths.home}/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/${i}.png`;
        return Quickshell.iconPath("application-x-executable", true);
    }

    // the icon for a window, from its class
    function iconForClass(cls: string): string {
        if (!cls)
            return "";
        const e = DesktopEntries.heuristicLookup(cls);
        return iconOf({
            id: cls
        }, e);
    }

    function nameForClass(cls: string): string {
        const e = cls ? DesktopEntries.heuristicLookup(cls) : null;
        return e?.name ?? cls.split(".").pop() ?? "";
    }

    function classesOf(app: var, entry: var): var {
        if (!app || app.match)
            return [];
        const ids = [app.id, entry?.startupClass, entry?.id].filter(x => x).map(x => x.toLowerCase().replace(/\.desktop$/, ""));
        if (app.id)
            ids.push(app.id.split(".").pop().toLowerCase());
        return ids;
    }

    function windowsOf(app: var, classes: var): var {
        if (!app)
            return [];
        const ids = classes ?? classesOf(app, entryOf(app));
        const match = app.match?.toLowerCase();
        return CosmicWindows.windows.filter(w => {
            const cls = (w.app_id ?? "").toLowerCase();
            return match ? cls.includes(match) : ids.includes(cls);
        });
    }

    function launch(app: var): void {
        if (app.command)
            Quickshell.execDetached(["distrobox-host-exec", "sh", "-c", app.command]);
        else if (app.id)
            Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", app.id.replace(/\.desktop$/, "")]);
    }

    function launchEntry(entry: var): void {
        launch({
            id: entry.id
        });
    }

    // a running app comes to the front (and cycles through its windows); otherwise it starts
    function open(app: var): void {
        const wins = windowsOf(app);
        if (wins.length > 0) {
            const at = wins.findIndex(w => w.id === CosmicWindows.activeId);
            CosmicWindows.activate(wins[(at + 1) % wins.length].id);
        } else {
            launch(app);
        }
    }

    function onHost(entry: var): bool {
        return !hostIds || hostIds.has(entry.id) || hostIds.has(entry.id.replace(/\.desktop$/, ""));
    }

    // every app the desktop shows, A-Z
    readonly property var all: [...DesktopEntries.applications.values].filter(a => !a.noDisplay && onHost(a)).sort((a, b) => a.name.localeCompare(b.name))

    function refreshHost(): void {
        hostApps.running = true;
    }

    function remove(i: int): void {
        if (i < 0 || i >= dock.length)
            return;
        const list = dock.slice();
        list.splice(i, 1);
        dock = list;
        save();
    }

    function save(): void {
        lastWritten = JSON.stringify(Object.assign({}, extra, {
            apps: dock
        }), null, 4) + "\n";
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
            dock = list;
        } catch (e) {
            console.warn("quill: dock.json is not valid JSON:", e);
        }
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

    Process {
        id: hostApps

        running: true
        command: ["sh", "-c", "ls -1 /run/host/usr/share/applications /run/host/usr/local/share/applications /run/host/var/lib/flatpak/exports/share/applications /run/host/var/lib/snapd/desktop/applications \"$HOME/.local/share/applications\" \"$HOME/.local/share/flatpak/exports/share/applications\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.split("\n").filter(l => l.endsWith(".desktop")).map(l => l.slice(0, -8));
                root.hostIds = new Set(ids);
            }
        }
    }
}
