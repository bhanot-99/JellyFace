pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.drift
import qs.drift.components

// The other videos in the folder of the one playing (a series' episodes, a course's lessons), in order, each with a
// still from the video (made once by scripts/video-thumbs.sh, cached). The playing one is marked and scrolled into view; click another to play it
// in the same player (or open it, when the player has closed).
Item {
    id: root

    property string url // file:// URL of the video playing
    property var player // its MPRIS player, if still open
    readonly property string file: url.startsWith("file://") ? decodeURIComponent(url.slice(7)) : ""
    readonly property string dir: file.slice(0, file.lastIndexOf("/"))
    readonly property string folderName: dir.slice(dir.lastIndexOf("/") + 1)
    property var videos: []
    property var thumbs: ({}) // path -> true once its still exists
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/jellyface/video-thumbs`

    function uriOf(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function thumbOf(path: string): string {
        return thumbs[path] ? `file://${cache}/${Qt.md5(path)}.jpg` : "";
    }

    function play(path: string): void {
        const uri = uriOf(path);
        if (player && player.openUri)
            player.openUri(uri);
        else
            Quickshell.execDetached(["distrobox-host-exec", "xdg-open", uri]);
    }

    // the command is built here, not bound: started in the same change, a binding could still hold the old folder
    function list(): void {
        videos = [];
        lister.running = false;
        if (!dir)
            return;
        lister.command = ["distrobox-host-exec", "sh", "-c", "find \"$1\" -maxdepth 1 -type f -iregex '.*\\.\\(mkv\\|mp4\\|webm\\|avi\\|mov\\|m4v\\|wmv\\|flv\\|mpg\\|mpeg\\|ts\\|ogv\\)' | sort -V | head -n 300", "list", dir];
        lister.running = true;
    }

    onDirChanged: list()
    Component.onCompleted: list()

    Process {
        id: lister

        // (runs on the host: the folder may be on a disk the container does not see)
        stdout: StdioCollector {
            onStreamFinished: {
                root.videos = text.split("\n").filter(l => l);
                root.thumbs = ({});
                // the playing one first, then its neighbours outwards
                const at = Math.max(0, root.videos.indexOf(root.file));
                const order = root.videos.map((v, i) => [Math.abs(i - at), v]).sort((a, b) => a[0] - b[0]).map(x => x[1]);
                thumber.command = ["distrobox-host-exec", Quickshell.shellPath("../scripts/video-thumbs.sh"), ...order.slice(0, 60)];
                thumber.running = true;
            }
        }
    }

    Process {
        id: thumber

        stdout: SplitParser {
            onRead: line => {
                const t = Object.assign({}, root.thumbs);
                t[line] = true;
                root.thumbs = t;
            }
        }
    }

    Row {
        id: head

        x: 16
        y: 14
        spacing: 8

        Icon {
            name: "video_library"
            size: 18
            color: Theme.accent
        }

        Label {
            text: root.folderName || "This folder"
            font.weight: Font.DemiBold
            width: Math.min(implicitWidth, root.width - 90)
        }

        Label {
            visible: root.videos.length > 0
            text: `${root.videos.indexOf(root.file) + 1} / ${root.videos.length}`
            size: Theme.small
            muted: true
        }
    }

    Label {
        visible: root.videos.length === 0
        anchors.centerIn: parent
        text: lister.running ? "Looking in the folder…" : "No other videos here"
        secondary: true
    }

    ListView {
        id: list

        x: 10
        y: 42
        width: parent.width - 20
        height: parent.height - 52
        clip: true
        spacing: 4
        model: root.videos
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: Qt.callLater(() => positionViewAtIndex(Math.max(0, root.videos.indexOf(root.file)), ListView.Center))

        delegate: Rectangle {
            id: row

            required property string modelData
            required property int index
            readonly property bool current: modelData === root.file
            readonly property string name: modelData.slice(modelData.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "")

            width: list.width
            height: 54
            radius: Theme.radiusRow
            color: current ? Theme.accentSoft : rowArea.containsMouse ? Theme.tileHover : "transparent"
            border.width: current ? 1 : 0
            border.color: Theme.accent

            Rectangle {
                id: thumb

                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 72
                height: 42
                radius: 8
                color: Theme.well
                clip: true

                Image {
                    id: shot

                    anchors.fill: parent
                    source: root.thumbOf(row.modelData)
                    sourceSize: Qt.size(144, 84)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Icon {
                    visible: shot.status !== Image.Ready
                    anchors.centerIn: parent
                    name: row.current ? "play_circle" : "movie"
                    size: 20
                    color: row.current ? Theme.accent : Theme.textMuted
                }

                Rectangle {
                    visible: row.current && shot.status === Image.Ready
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.35)

                    Icon {
                        anchors.centerIn: parent
                        name: "graphic_eq"
                        size: 20
                        color: "#FFFFFF"
                    }
                }
            }

            Label {
                anchors.left: thumb.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.name
                size: Theme.small
                font.weight: row.current ? Font.DemiBold : Font.Normal
                color: row.current ? Theme.accent : Theme.text
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            MouseArea {
                id: rowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!row.current) root.play(row.modelData)
            }
        }
    }
}
