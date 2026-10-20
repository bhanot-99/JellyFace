pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.quill
import qs.quill.components

// The other videos in the folder of the one playing (a series' episodes, a course's lessons), in order, by name. The playing one is marked and scrolled into view; click another to play it
// in the same player (or open it, when the player has closed).
Item {
    id: root

    property string url // file:// URL of the video playing
    property var player // its MPRIS player, if still open
    readonly property string file: url.startsWith("file://") ? decodeURIComponent(url.slice(7)) : ""
    readonly property string dir: file.slice(0, file.lastIndexOf("/"))
    readonly property string folderName: dir.slice(dir.lastIndexOf("/") + 1)
    property var videos: []

    function uriOf(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function play(path: string): void {
        const uri = uriOf(path);
        if (player && player.openUri)
            player.openUri(uri);
        else
            Quickshell.execDetached(["distrobox-host-exec", "xdg-open", uri]);
    }

    // the command is built here, not bound: started in the same change, a binding could still hold the old folder
    function scan(): void {
        videos = [];
        lister.running = false;
        if (!dir)
            return;
        lister.command = ["distrobox-host-exec", "sh", "-c", "find \"$1\" -maxdepth 1 -type f -iregex '.*\\.\\(mkv\\|mp4\\|webm\\|avi\\|mov\\|m4v\\|wmv\\|flv\\|mpg\\|mpeg\\|ts\\|ogv\\)' | sort -V | head -n 300", "list", dir];
        lister.running = true;
    }

    onDirChanged: scan()
    Component.onCompleted: scan()

    Process {
        id: lister

        // (runs on the host: the folder may be on a disk the container does not see)
        stdout: StdioCollector {
            onStreamFinished: {
                root.videos = text.split("\n").filter(l => l);
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
            height: 40
            radius: Theme.radiusRow
            color: current ? Theme.accentSoft : rowArea.containsMouse ? Theme.tileHover : "transparent"
            border.width: current ? 1 : 0
            border.color: Theme.accent

            Icon {
                id: thumb

                x: 10
                anchors.verticalCenter: parent.verticalCenter
                name: row.current ? "graphic_eq" : "movie"
                size: 18
                color: row.current ? Theme.accent : Theme.textMuted
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
