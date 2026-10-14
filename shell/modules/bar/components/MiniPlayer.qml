pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Jellyface.Config
import qs.components
import qs.services

// Round cover thumbnail with a progress ring; only shown while a player has a track.
// Left click: play/pause. Right click: open the dashboard's Media tab. Scroll: next/previous track.
Item {
    id: root

    required property ScreenState screenState

    readonly property var player: Players.active
    readonly property bool present: !!player && (player.isPlaying || player.playbackState === MprisPlaybackState.Paused) && !!(player.trackTitle ?? "")
    readonly property real size: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    property real progress: {
        const p = root.player;
        return p?.length ? Math.min(1, (p.position % p.length) / p.length) : 0;
    }

    visible: present
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: present ? Tokens.sizes.bar.innerWidth : 0

    Timer {
        running: root.present && (root.player?.isPlaying ?? false)
        interval: 1000
        triggeredOnStart: true
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    onProgressChanged: ring.requestPaint()
    onPresentChanged: ring.requestPaint()

    StyledClippingRect {
        id: cover

        anchors.centerIn: parent
        implicitWidth: root.size - 6
        implicitHeight: implicitWidth
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        Image {
            anchors.fill: parent
            source: Players.getArtUrl(root.player)
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !(root.player && Players.getArtUrl(root.player))
            text: "music_note"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("black", 0.45)
            opacity: area.containsMouse ? 1 : 0

            Behavior on opacity {
                Anim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.player?.isPlaying ? "pause" : "play_arrow"
                color: "white"
                fill: 1
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    Canvas {
        id: ring

        anchors.centerIn: parent
        width: root.size
        height: root.size
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root.present)
                return;
            const r = width / 2 - 1.5;
            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            ctx.strokeStyle = Qt.alpha(Colours.palette.m3outline, 0.4);
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
            ctx.stroke();
            ctx.strokeStyle = Colours.palette.m3primary;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * root.progress);
            ctx.stroke();
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                root.screenState.dashboardTab = 1;
                root.screenState.dashboard = true;
            } else if (root.player?.canTogglePlaying) {
                root.player.togglePlaying();
            }
        }
        onWheel: event => {
            if (event.angleDelta.y < 0 && root.player?.canGoNext)
                root.player.next();
            else if (event.angleDelta.y > 0 && root.player?.canGoPrevious)
                root.player.previous();
        }
    }
}
