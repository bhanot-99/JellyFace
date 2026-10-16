pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.utils

// Dynamic Island: Contextual floating status capsule at top center of the screen,
// modeled on the authentic Apple iPhone Dynamic Island UI/UX.
// Morphs smoothly between an ambient compact pill (artwork, animated equalizer bars)
// and an expanded interactive media card (scrubber, timestamps, tactile controls).
Scope {
    id: root

    readonly property MprisPlayer player: Players.active
    readonly property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: player && (isPlaying || player.playbackState === MprisPlaybackState.Paused)
    readonly property bool wanted: hasMedia && !CosmicWindows.fullscreen

    function formatTime(s: real): string {
        if (!s || isNaN(s) || s < 0)
            return "0:00";
        const mins = Math.floor(s / 60);
        const secs = Math.floor(s % 60).toString().padStart(2, "0");
        return `${mins}:${secs}`;
    }

    StyledWindow {
        id: win

        screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
        name: "dynamic-island"
        visible: root.wanted
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        margins.top: 8

        implicitWidth: islandCapsule.width
        implicitHeight: islandCapsule.height
        mask: Region {
            item: islandCapsule
        }

        BackgroundEffect.blurRegion: blurRegion

        Region {
            id: blurRegion

            item: islandCapsule
        }

        StyledRect {
            id: islandCapsule

            property bool expanded: false

            width: expanded ? 370 : (root.isPlaying ? 200 : 180)
            height: expanded ? 166 : 36
            radius: expanded ? 36 : height / 2
            color: "#000000"
            border.color: Qt.rgba(255, 255, 255, 0.14)
            border.width: 1
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutQuart
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutQuart
                }
            }

            Behavior on radius {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutQuart
                }
            }

            GlassBevel {
                radius: islandCapsule.radius
            }

            Timer {
                id: collapseTimer

                interval: 6000
                onTriggered: islandCapsule.expanded = false
            }

            // Compact Pill View (Artwork on Left + Apple Soundwave Bars on Right)
            Item {
                id: compactView

                anchors.fill: parent
                visible: opacity > 0
                opacity: islandCapsule.expanded ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                // Mini Album Artwork or Music Icon
                Rectangle {
                    id: miniArt

                    width: 24
                    height: 24
                    radius: 6
                    color: "#1C1C1E"
                    clip: true
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    border.color: Qt.rgba(255, 255, 255, 0.15)
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        source: root.player ? Players.getArtUrl(root.player) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "music_note"
                        color: "#FA586A"
                        font.pointSize: 13
                        visible: !parent.children[0].source
                    }
                }

                // Apple Signature Equalizer Waveform Bars
                Row {
                    id: eqBars

                    property real tick: 0

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2.5

                    Timer {
                        interval: 80
                        running: root.isPlaying && !islandCapsule.expanded
                        repeat: true
                        onTriggered: eqBars.tick = (eqBars.tick + 1) % 1000
                    }

                    Repeater {
                        model: 4

                        Rectangle {
                            id: eqBar

                            required property int index

                            width: 3.2
                            radius: 1.6
                            color: "#30D158"
                            anchors.bottom: parent.bottom
                            height: {
                                if (!root.isPlaying)
                                    return 3.5;
                                const t = eqBars.tick;
                                if (index === 0)
                                    return 4 + Math.abs(Math.sin(t * 0.35)) * 12;
                                if (index === 1)
                                    return 5 + Math.abs(Math.sin(t * 0.48 + 1.2)) * 14;
                                if (index === 2)
                                    return 4 + Math.abs(Math.sin(t * 0.30 + 2.5)) * 13;
                                return 3.5 + Math.abs(Math.sin(t * 0.55 + 0.8)) * 11;
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: 75
                                }
                            }
                        }
                    }
                }

                // Compact Pill tap area to expand
                MouseArea {
                    anchors.fill: parent
                    enabled: !islandCapsule.expanded
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        islandCapsule.expanded = true;
                        collapseTimer.restart();
                    }
                }
            }

            // Expanded Bento Card View
            Item {
                id: expandedView

                anchors.fill: parent
                anchors.margins: 14
                visible: opacity > 0
                opacity: islandCapsule.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Tier 1: Media Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Large Album Artwork
                        Rectangle {
                            id: largeArt

                            width: 52
                            height: 52
                            radius: 12
                            color: "#1C1C1E"
                            clip: true
                            border.color: Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                source: root.player ? Players.getArtUrl(root.player) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "album"
                                color: Qt.rgba(255, 255, 255, 0.4)
                                font.pointSize: 26
                                visible: !parent.children[0].source
                            }
                        }

                        // Track Title & Artist
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.player?.trackTitle || Tr.tr("Nothing Playing")
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.player?.trackArtist || root.player?.identity || Tr.tr("Unknown Artist")
                                font.pixelSize: 12
                                color: "#98989D"
                                elide: Text.ElideRight
                            }
                        }

                        // Route badge
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: Qt.rgba(255, 255, 255, 0.12)
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "airplay"
                                color: "#30D158"
                                font.pointSize: 15
                            }
                        }
                    }

                    // Tier 2: Timeline Scrubber
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            text: root.formatTime(root.player?.position ?? 0)
                            font.pixelSize: 11
                            color: "#8E8E93"
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            id: scrubBar

                            readonly property real progress: {
                                if (!root.player || !root.player.length || root.player.length <= 0)
                                    return 0;
                                return Math.max(0, Math.min(1, root.player.position / root.player.length));
                            }

                            Layout.fillWidth: true
                            height: 16

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 4
                                radius: 2
                                color: "#38383A"

                                Rectangle {
                                    height: parent.height
                                    radius: 2
                                    color: "#FFFFFF"
                                    width: parent.width * scrubBar.progress
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: mouse => {
                                    if (!root.player || !root.player.length || root.player.length <= 0)
                                        return;
                                    const ratio = Math.max(0, Math.min(1, mouse.x / width));
                                    root.player.position = ratio * root.player.length;
                                    collapseTimer.restart();
                                }
                                onPositionChanged: mouse => {
                                    if (pressed && root.player && root.player.length > 0) {
                                        const ratio = Math.max(0, Math.min(1, mouse.x / width));
                                        root.player.position = ratio * root.player.length;
                                        collapseTimer.restart();
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: {
                                const len = root.player?.length ?? 0;
                                const pos = root.player?.position ?? 0;
                                if (len <= 0)
                                    return "--:--";
                                return "-" + root.formatTime(Math.max(0, len - pos));
                            }
                            font.pixelSize: 11
                            color: "#8E8E93"
                            Layout.preferredWidth: 36
                        }
                    }

                    // Tier 3: Controls
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter

                        Item {
                            Layout.fillWidth: true
                        }

                        Row {
                            spacing: 24
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                id: prevIcon

                                anchors.verticalCenter: parent.verticalCenter
                                text: "skip_previous"
                                color: prevArea.containsMouse ? "#FFFFFF" : Qt.rgba(255, 255, 255, 0.8)
                                font.pointSize: 22

                                MouseArea {
                                    id: prevArea

                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.player?.previous();
                                        collapseTimer.restart();
                                    }
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 44
                                radius: 22
                                color: playArea.containsMouse ? "#FFFFFF" : Qt.rgba(255, 255, 255, 0.92)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: root.isPlaying ? "pause" : "play_arrow"
                                    color: "#000000"
                                    font.pointSize: 24
                                }

                                MouseArea {
                                    id: playArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.player?.playPause();
                                        collapseTimer.restart();
                                    }
                                }
                            }

                            MaterialIcon {
                                id: nextIcon

                                anchors.verticalCenter: parent.verticalCenter
                                text: "skip_next"
                                color: nextArea.containsMouse ? "#FFFFFF" : Qt.rgba(255, 255, 255, 0.8)
                                font.pointSize: 22

                                MouseArea {
                                    id: nextArea

                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.player?.next();
                                        collapseTimer.restart();
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        MaterialIcon {
                            Layout.alignment: Qt.AlignVCenter
                            text: "expand_less"
                            color: collapseArea.containsMouse ? "#FFFFFF" : "#8E8E93"
                            font.pointSize: 18

                            MouseArea {
                                id: collapseArea

                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandCapsule.expanded = false
                            }
                        }
                    }
                }
            }

            // Expanded hover watcher to keep island open during active mouse presence
            MouseArea {
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                enabled: islandCapsule.expanded
                onPositionChanged: {
                    if (islandCapsule.expanded)
                        collapseTimer.restart();
                }
            }
        }
    }
}
