pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Jellyface.Services
import qs.services
import qs.drift
import qs.drift.components

// Dashboard tab 2 — Media: the cover with a live visualiser under it, the track, a seek bar, the controls (shuffle,
// previous, play, next, repeat), the players to choose from, and synced lyrics (click a line to jump there).
// Space plays or pauses, ←/→ skip.
Item {
    id: root

    readonly property var player: Players.active
    readonly property bool hasLength: !!player && player.length > 0 && player.length < 2147483647

    implicitWidth: 820
    implicitHeight: 360

    function move(dx: int, dy: int): void {
        if (dx < 0)
            player?.previous();
        else if (dx > 0)
            player?.next();
    }

    function press(): void {
        player?.togglePlaying();
    }

    function time(s: real): string {
        s = Math.max(0, Math.floor(s));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // the visualiser and the position only run while this tab is on screen
    ServiceRef {
        service: root.visible && root.player?.isPlaying ? Audio.cava : null
    }

    Timer {
        running: root.visible && !!root.player?.isPlaying
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    // lyrics follow the track
    readonly property var _lyrics: {
        if (!visible)
            return null;
        const p = player;
        if (p)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        else
            Lyrics.clearTrack();
        return null;
    }

    Column {
        visible: !root.player
        anchors.centerIn: parent
        spacing: 10

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "music_off"
            size: 44
            color: Theme.textMuted
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing is playing"
            size: Theme.heading
            secondary: true
        }
    }

    // ── cover and visualiser ──
    Item {
        id: coverBox

        visible: !!root.player
        width: 250
        height: parent.height

        Rectangle {
            id: cover

            width: 250
            height: 250
            radius: 28
            color: Theme.lilac
            clip: true

            Image {
                anchors.fill: parent
                source: root.player ? Players.getArtUrl(root.player) : ""
                sourceSize: Qt.size(500, 500)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.player || !Players.getArtUrl(root.player)
                name: "album"
                size: 72
                color: Qt.rgba(1, 1, 1, 0.8)
            }
        }

        Row {
            anchors.top: cover.bottom
            anchors.topMargin: 18
            anchors.horizontalCenter: cover.horizontalCenter
            height: 70
            spacing: 4

            Repeater {
                model: 28

                Rectangle {
                    required property int index
                    readonly property real v: root.player?.isPlaying ? Math.max(0.05, Math.min(1, Audio.cava.values[index] ?? 0)) : 0.05

                    anchors.bottom: parent.bottom
                    width: 5
                    height: Math.max(4, v * 70)
                    radius: 2.5
                    color: Theme.accent
                    opacity: 0.45 + v * 0.55

                    Behavior on height {
                        Anim { duration: 90 }
                    }
                }
            }
        }
    }

    // ── track, seek bar, controls, players ──
    Column {
        id: info

        visible: !!root.player
        x: coverBox.width + 28
        width: 290
        spacing: 14

        Column {
            width: parent.width
            spacing: 4

            Kicker {
                text: Players.getIdentity(root.player)
            }

            Label {
                width: parent.width
                text: root.player?.trackTitle || "Unknown title"
                size: Theme.title
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Label {
                width: parent.width
                text: root.player?.trackArtist || "Unknown artist"
                size: Theme.heading
                secondary: true
            }

            Label {
                visible: text !== ""
                width: parent.width
                text: root.player?.trackAlbum ?? ""
                size: Theme.small
                muted: true
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Slider {
                width: parent.width
                enabled: root.hasLength && !!root.player?.canSeek
                showBubble: true
                bubbleText: root.time(shown * (root.player?.length ?? 0))
                value: root.hasLength ? (root.player.position / root.player.length) : 0
                onReleased: v => {
                    if (root.player && root.hasLength)
                        root.player.position = v * root.player.length;
                }
            }

            Item {
                width: parent.width
                height: 16

                Label {
                    text: root.time(root.player?.position ?? 0)
                    size: Theme.caption + 1
                    muted: true
                }

                Label {
                    anchors.right: parent.right
                    text: root.hasLength ? root.time(root.player.length) : "--:--"
                    size: Theme.caption + 1
                    muted: true
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.player?.shuffleSupported
                size: 36
                icon: "shuffle"
                active: !!root.player?.shuffle
                onClicked: root.player.shuffle = !root.player.shuffle
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 44
                icon: "skip_previous"
                onClicked: root.player?.previous()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 58
                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                active: true
                onClicked: root.player?.togglePlaying()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 44
                icon: "skip_next"
                onClicked: root.player?.next()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.player?.loopSupported
                size: 36
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                active: root.player ? root.player.loopState !== MprisLoopState.None : false
                onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        // more than one player: choose
        Flow {
            visible: Players.list.length > 1
            width: parent.width
            spacing: 6

            Repeater {
                model: Players.list

                Pill {
                    id: choice

                    required property var modelData

                    interactive: true
                    active: modelData === root.player
                    onClicked: Players.manualActive = modelData

                    Label {
                        text: Players.getIdentity(choice.modelData)
                        size: Theme.small
                    }
                }
            }
        }
    }

    // ── lyrics ──
    Tile {
        visible: !!root.player
        anchors.right: parent.right
        width: parent.width - info.x - info.width - 24
        height: parent.height
        interactive: false
        clip: true

        Kicker {
            x: 16
            y: 14
            text: "Lyrics"
        }

        Label {
            visible: !Lyrics.hasLyrics
            anchors.centerIn: parent
            text: Lyrics.loading ? "Looking for lyrics…" : "No lyrics for this track"
            secondary: true
        }

        ListView {
            id: lyrics

            visible: Lyrics.hasLyrics
            x: 12
            y: 38
            width: parent.width - 24
            height: parent.height - 50
            clip: true
            model: Lyrics.lyrics
            spacing: 8
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: height * 0.35
            preferredHighlightEnd: height * 0.5
            highlightMoveDuration: 300
            currentIndex: Lyrics.indexForTime(root.player?.position ?? 0)

            delegate: Text {
                required property string modelData
                required property int index
                readonly property bool now: index === lyrics.currentIndex

                width: lyrics.width
                text: modelData || "♪"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: now ? 17 : 14
                font.weight: now ? Font.DemiBold : Font.Normal
                color: now ? Theme.accent : Theme.textSecondary
                opacity: now ? 1 : 0.7

                Behavior on font.pixelSize {
                    Anim { duration: Theme.fast }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player)
                            root.player.position = Lyrics.timeForIndex(parent.index);
                    }
                }
            }
        }
    }
}
