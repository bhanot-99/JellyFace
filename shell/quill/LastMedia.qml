pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// What was playing last, so the dashboard's Media tab still shows it after the player closed (and after a restart):
// ~/.local/state/jellyface/quill-last-media.json. `resume()` opens the app it came from again.
Singleton {
    id: root

    property string title
    property string artist
    property string album
    property string art
    property string identity
    property string entry // desktop entry of the player
    property string url // what is playing: a file:// path for local media, http(s) for online
    property real length
    property real position
    readonly property bool known: title !== ""

    function remember(p: var): void {
        if (!p || !p.trackTitle)
            return;
        const cover = Players.getArtUrl(p);
        const changed = root.title !== p.trackTitle || root.artist !== (p.trackArtist ?? "") || root.identity !== Players.getIdentity(p);
        const before = [root.title, root.artist, root.album, root.art, root.identity, root.entry, root.url, root.length].join("\n");
        root.title = p.trackTitle;
        root.artist = p.trackArtist ?? "";
        root.album = p.trackAlbum ?? "";
        // a new track without its cover yet must not keep the previous one
        root.art = cover || (changed ? "" : root.art);
        root.identity = Players.getIdentity(p);
        root.entry = p.desktopEntry ?? "";
        root.length = p.length > 0 && p.length < 2147483647 ? p.length : 0;
        root.position = p.position ?? 0;
        root.url = String(p.metadata?.["xesam:url"] ?? "");
        // the track itself is written at once; only the position moving on waits for the next save (every 30 s)
        if ([root.title, root.artist, root.album, root.art, root.identity, root.entry, root.url, root.length].join("\n") !== before)
            saveTimer.restart();
    }

    function resume(): void {
        // a local file plays again where it was; otherwise the player opens
        if (url.startsWith("file://"))
            Quickshell.execDetached(["distrobox-host-exec", "xdg-open", url]);
        else if (entry)
            Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", entry]);
    }

    Connections {
        function onTrackTitleChanged(): void {
            root.remember(Players.active);
        }

        function onTrackArtistChanged(): void {
            root.remember(Players.active);
        }

        function onMetadataChanged(): void {
            root.remember(Players.active);
        }

        function onTrackArtUrlChanged(): void {
            root.remember(Players.active);
        }

        // paused or stopped: keep where it stopped
        function onIsPlayingChanged(): void {
            root.remember(Players.active);
            saveTimer.restart();
        }

        target: Players.active
        ignoreUnknownSignals: true
    }

    Connections {
        function onActiveChanged(): void {
            root.remember(Players.active);
        }

        target: Players
    }

    // the position, now and then, so "last played" can say where it stopped (and the file follows every 30 s: no need
    // to write the disk every few seconds for as long as music plays)
    Timer {
        running: !!Players.active?.isPlaying
        interval: 5000
        repeat: true
        property int ticks
        onTriggered: {
            Players.active?.positionChanged();
            root.remember(Players.active);
            if (++ticks % 6 === 0)
                saveTimer.restart();
        }
    }

    Timer {
        id: saveTimer

        interval: 1500
        onTriggered: file.setText(JSON.stringify({
                title: root.title,
                artist: root.artist,
                album: root.album,
                art: root.art,
                identity: root.identity,
                entry: root.entry,
                url: root.url,
                length: root.length,
                position: root.position
            }))
    }

    FileView {
        id: file

        path: `${Paths.state}/quill-last-media.json`
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (root.known)
                return;
            try {
                const d = JSON.parse(text());
                for (const k of ["title", "artist", "album", "art", "identity", "entry", "url", "length", "position"])
                    if (d[k] !== undefined)
                        root[k] = d[k];
            } catch (e) {}
        }
    }

    Component.onCompleted: remember(Players.active)
}
