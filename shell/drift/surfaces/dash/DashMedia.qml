pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import M3Shapes
import Jellyface.Config
import Jellyface.Services
import qs.components.effects
import qs.services
import qs.drift
import qs.drift.components

// Dashboard tab 2 — Media: Classic's player in Drift's look. Pastel shapes drift behind it while something plays; the
// cover turns inside a ring of visualiser bars; title, artist and album; a wavy progress bar; shuffle, previous, a
// big play button, next and repeat; synced lyrics (click a line to jump there) and the player to control.
// When the player has closed, the last track stays here ("Last played"), and play opens its app again.
// Space plays or pauses, ←/→ skip.
Item {
    id: root

    readonly property var player: Players.active
    readonly property bool live: !!player
    readonly property bool playing: !!player?.isPlaying
    readonly property bool hasLength: live ? player.length > 0 && player.length < 2147483647 : LastMedia.length > 0
    readonly property real length: live ? player.length : LastMedia.length
    readonly property real position: live ? player.position : LastMedia.position
    readonly property string title: live ? player.trackTitle || LastMedia.title : LastMedia.title
    readonly property string artist: live ? player.trackArtist : LastMedia.artist
    readonly property string album: live ? player.trackAlbum : LastMedia.album
    readonly property string art: live ? Players.getArtUrl(player) || (player.trackTitle === LastMedia.title ? LastMedia.art : "") : LastMedia.art
    readonly property bool empty: !live && !LastMedia.known
    // what is playing as a URL: a local video gets its folder's other videos where the lyrics would be
    readonly property string url: live ? String(player.metadata?.["xesam:url"] ?? "") : LastMedia.url
    readonly property bool localVideo: url.startsWith("file://") && /\.(mkv|mp4|webm|avi|mov|m4v|wmv|flv|mpe?g|ts|ogv)$/i.test(url)

    implicitWidth: 820
    implicitHeight: 340

    function move(dx: int, dy: int): void {
        if (dx < 0)
            player?.previous();
        else if (dx > 0)
            player?.next();
    }

    function press(): void {
        if (live)
            player.togglePlaying();
        else
            LastMedia.resume();
    }

    function time(s: real): string {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    // the visualiser and the position only run while this tab is on screen and something plays
    ServiceRef {
        service: root.visible && root.playing ? Audio.cava : null
    }

    Timer {
        running: root.visible && root.playing
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    // lyrics follow the track
    readonly property var _lyrics: {
        if (!visible)
            return null;
        if (title && !localVideo)
            Lyrics.setTrack(artist ?? "", title, album ?? "", length);
        else
            Lyrics.clearTrack();
        return null;
    }

    // ── drifting pastel shapes behind everything ──
    Item {
        id: shapes

        readonly property list<int> pool: [MaterialShape.Circle, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie9Sided, MaterialShape.Sunny, MaterialShape.SoftBurst, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Arch, MaterialShape.Pill, MaterialShape.Fan, MaterialShape.Oval]
        readonly property list<color> tints: [Theme.lilac, Theme.ice, Theme.rose, Theme.peach, Theme.sage]

        anchors.fill: parent
        anchors.margins: -20
        clip: true
        opacity: 0.45

        Repeater {
            id: drifters

            model: 12

            MaterialShape {
                id: drifter

                required property int index
                property real vx: (6 + Math.random() * 12) * (Math.random() < 0.5 ? -1 : 1)
                property real vy: (6 + Math.random() * 12) * (Math.random() < 0.5 ? -1 : 1)
                property real vr: -10 + Math.random() * 20

                implicitSize: 40 + index * 8
                shape: shapes.pool[index % shapes.pool.length]
                color: shapes.tints[index % shapes.tints.length]
                opacity: 0.45
                rotation: Math.random() * 360
                // spread out once the tab has a size (placed at 0 x 0 they all piled up in a corner)
                property bool placed
                function place(): void {
                    if (placed || shapes.width <= 0)
                        return;
                    x = Math.random() * (shapes.width - implicitSize);
                    y = Math.random() * (shapes.height - implicitSize);
                    placed = true;
                }
                Component.onCompleted: place()
                Connections {
                    function onWidthChanged(): void {
                        drifter.place();
                    }

                    target: shapes
                }
            }
        }

        FrameAnimation {
            running: root.visible && root.playing
            onTriggered: {
                for (let i = 0; i < drifters.count; i++) {
                    const s = drifters.itemAt(i);
                    if (!s)
                        continue;
                    s.x += s.vx * frameTime;
                    s.y += s.vy * frameTime;
                    s.rotation += s.vr * frameTime;
                    if (s.x + s.width < 0)
                        s.x = shapes.width;
                    else if (s.x > shapes.width)
                        s.x = -s.width;
                    if (s.y + s.height < 0)
                        s.y = shapes.height;
                    else if (s.y > shapes.height)
                        s.y = -s.height;
                }
            }
        }
    }

    // ── nothing ever played ──
    Column {
        visible: root.empty
        anchors.centerIn: parent
        spacing: 10

        MaterialShape {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitSize: 96
            shape: MaterialShape.ClamShell
            color: Theme.accentSoft

            Icon {
                anchors.centerIn: parent
                name: "queue_music"
                size: 40
                color: Theme.accent
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            size: Theme.title
            font.weight: Font.DemiBold
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Play something for it to show up here!"
            secondary: true
        }
    }

    // ── the cover inside a ring of visualiser bars ──
    Item {
        id: disc

        readonly property int bars: GlobalConfig.services.visualiserBars
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real reach: (width - cover.width) / 2 - 10

        visible: !root.empty
        width: 228
        height: parent.height

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            data: rays.instances
        }

        Variants {
            id: rays

            model: Array.from({
                length: disc.bars
            }, (_, i) => i)

            ShapePath {
                id: ray

                required property int modelData
                readonly property real value: root.playing ? Math.max(0.02, Math.min(1, Audio.cava.values[modelData] ?? 0)) : 0.02
                readonly property real angle: modelData * 2 * Math.PI / disc.bars
                readonly property real edge: {
                    coverShape.rotation; // follow the turning cover
                    return coverShape.distanceAtAngle(modelData * 360 / disc.bars + 90) + 8 + strokeWidth / 2;
                }
                readonly property real cos: Math.cos(angle)
                readonly property real sin: Math.sin(angle)

                capStyle: ShapePath.RoundCap
                strokeWidth: Math.max(2, 360 / disc.bars - 2)
                strokeColor: Qt.alpha(Theme.accent, 0.35 + value * 0.65)
                startX: disc.cx + edge * cos
                startY: disc.cy + edge * sin

                PathLine {
                    x: disc.cx + (ray.edge + ray.value * disc.reach) * ray.cos
                    y: disc.cy + (ray.edge + ray.value * disc.reach) * ray.sin
                }
            }
        }

        Item {
            id: cover

            anchors.centerIn: parent
            width: 158
            height: 158

            Item {
                id: coverMask

                anchors.fill: parent
                layer.enabled: true
                visible: false

                MaterialShape {
                    id: coverShape

                    implicitSize: cover.width
                    shape: MaterialShape.Cookie9Sided
                    color: "white"

                    // one turn in 23.5 s while playing; stops where it is when paused
                    FrameAnimation {
                        running: root.visible && root.playing
                        onTriggered: coverShape.rotation = (coverShape.rotation - frameTime * 360 / 23.5) % 360
                    }
                }
            }

            MaterialShape {
                implicitSize: cover.width
                rotation: coverShape.rotation
                shape: MaterialShape.Cookie9Sided
                color: Theme.lilac
            }

            Icon {
                visible: art.status !== Image.Ready
                anchors.centerIn: parent
                name: root.live ? "art_track" : "history"
                size: 64
                color: "#FFFFFF"
            }

            Image {
                id: art

                anchors.fill: parent
                source: root.art
                sourceSize: Qt.size(380, 380)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                layer.enabled: true
                layer.effect: Mask {
                    maskSource: coverMask
                }

                Behavior on opacity {
                    Anim {}
                }
            }
        }
    }

    // ── the track and the controls ──
    Column {
        id: details

        visible: !root.empty
        x: disc.width + 10
        anchors.verticalCenter: parent.verticalCenter
        width: 326
        spacing: 4

        Kicker {
            text: root.live ? (root.playing ? `Now playing · ${Players.getIdentity(root.player)}` : `Paused · ${Players.getIdentity(root.player)}`) : `Last played · ${LastMedia.identity}`
        }

        Label {
            width: parent.width
            text: root.title || "Unknown title"
            size: Theme.title
            font.weight: Font.DemiBold
        }

        Label {
            width: parent.width
            text: root.artist || "Unknown artist"
            size: Theme.heading
            secondary: true
        }

        Label {
            width: parent.width
            text: root.album || "Unknown album"
            size: Theme.heading
            color: Theme.accent
        }

        Item {
            width: 1
            height: 16
        }

        Row {
            width: parent.width
            spacing: 10

            Label {
                id: pos

                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignHCenter
                text: root.time(seek.dragging ? seek.dragValue * root.length : root.position)
                size: Theme.small
                secondary: true
            }

            WavySlider {
                id: seek

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 108
                enabled: root.live && root.hasLength && !!root.player?.canSeek
                flowing: root.playing
                value: root.hasLength ? root.position / root.length : 0
                onReleased: v => {
                    if (root.player?.canSeek)
                        root.player.position = v * root.length;
                }
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignHCenter
                text: root.hasLength ? root.time(root.length) : "--:--"
                size: Theme.small
                secondary: true
            }
        }

        Item {
            width: 1
            height: 12
        }

        Row {
            width: parent.width
            spacing: 8

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 44
                icon: "shuffle"
                active: !!root.player?.shuffle
                opacity: root.player?.shuffleSupported ? 1 : 0.4
                enabled: !!root.player?.shuffleSupported
                onClicked: root.player.shuffle = !root.player.shuffle
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 50
                icon: "skip_previous"
                opacity: root.player?.canGoPrevious ? 1 : 0.4
                enabled: !!root.player?.canGoPrevious
                onClicked: root.player.previous()
            }

            // the big play button fills the space between, as on Classic's
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 * 2 - 50 * 2 - 8 * 4
                height: 56
                radius: root.playing ? 18 : 28
                color: playArea.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
                opacity: root.live || LastMedia.entry ? 1 : 0.4

                Behavior on radius {
                    Anim {}
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.playing ? "pause" : "play_arrow"
                        size: 28
                        filled: true
                        color: "#FFFFFF"
                    }

                    Label {
                        visible: !root.live
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open"
                        color: "#FFFFFF"
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: playArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.press()
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 50
                icon: "skip_next"
                opacity: root.player?.canGoNext ? 1 : 0.4
                enabled: !!root.player?.canGoNext
                onClicked: root.player.next()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 44
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                active: root.live && root.player.loopState !== MprisLoopState.None
                opacity: root.player?.loopSupported ? 1 : 0.4
                enabled: !!root.player?.loopSupported
                onClicked: {
                    const s = root.player.loopState;
                    root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Track : s === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None;
                }
            }
        }
    }

    // ── lyrics and the player ──
    Tile {
        visible: !root.empty
        x: details.x + details.width + 18
        width: parent.width - x
        height: parent.height
        interactive: false
        clip: true

        Row {
            visible: !root.localVideo
            x: 16
            y: 14
            spacing: 8

            Icon {
                name: "lyrics"
                size: 18
                color: Theme.accent
            }

            Label {
                text: "Lyrics"
                font.weight: Font.DemiBold
            }
        }

        Label {
            visible: !root.localVideo && !Lyrics.hasLyrics
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -16
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Lyrics.loading ? "Looking for lyrics…" : "No lyrics for this track"
            secondary: true
        }

        ListView {
            id: lyrics

            visible: !root.localVideo && Lyrics.hasLyrics
            x: 14
            y: 44
            width: parent.width - 28
            height: parent.height - 44 - picker.height - 22
            clip: true
            model: Lyrics.lyrics
            spacing: 8
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: height * 0.35
            preferredHighlightEnd: height * 0.5
            highlightMoveDuration: 300
            currentIndex: Lyrics.indexForTime(root.position)

            delegate: Text {
                id: line

                required property string modelData
                required property int index
                readonly property bool now: index === lyrics.currentIndex

                width: lyrics.width
                text: modelData || "♪"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: now ? 16 : 13
                font.weight: now ? Font.DemiBold : Font.Normal
                color: now ? Theme.accent : Theme.textSecondary
                opacity: now ? 1 : 0.75

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player)
                            root.player.position = Lyrics.timeForIndex(line.index);
                    }
                }
            }
        }

        FolderVideos {
            visible: root.localVideo
            width: parent.width
            height: parent.height - picker.height - 18
            url: root.localVideo ? root.url : ""
            player: root.player
        }

        // the player being controlled; click to choose another (when there are several)
        Pill {
            id: picker

            property bool open

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            height: 34
            interactive: Players.list.length > 1
            color: Theme.tile
            onClicked: open = !open

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.live ? "graphic_eq" : "music_off"
                size: 16
                color: Theme.accent
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.live ? Players.getIdentity(root.player) : "No players"
                size: Theme.small
                font.weight: Font.Medium
                width: Math.min(implicitWidth, 150)
            }

            Icon {
                visible: Players.list.length > 1
                anchors.verticalCenter: parent.verticalCenter
                name: picker.open ? "expand_more" : "expand_less"
                size: 16
            }
        }

        Glass {
            visible: picker.open && Players.list.length > 1
            anchors.horizontalCenter: picker.horizontalCenter
            anchors.bottom: picker.top
            anchors.bottomMargin: 6
            width: 200
            height: choices.implicitHeight + 12
            radius: 16
            color: Theme.sheet
            shadowStrength: 0.6

            Column {
                id: choices

                x: 6
                y: 6
                width: parent.width - 12

                Repeater {
                    model: Players.list

                    ListRow {
                        required property var modelData

                        width: choices.width
                        rowHeight: 34
                        icon: modelData === root.player ? "check" : "music_note"
                        title: Players.getIdentity(modelData)
                        onClicked: {
                            Players.manualActive = modelData;
                            picker.open = false;
                        }
                    }
                }
            }
        }
    }
}
