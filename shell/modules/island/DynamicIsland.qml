pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Jellyface.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.utils

// Dynamic Island: Contextual floating frosted-glass status capsule at the top center of the screen.
// Morphs smoothly between an ambient compact pill (live equalizer bars, mini track info)
// and an expanded interactive media card (scrubber, controls, album art).
Scope {
    id: root

    readonly property MprisPlayer player: Players.active
    readonly property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: player && (isPlaying || player.playbackState === MprisPlaybackState.Paused)
    readonly property bool wanted: hasMedia && !CosmicWindows.fullscreen

    StyledWindow {
        id: win

        screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
        name: "dynamic-island"
        visible: root.wanted
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

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

            width: expanded ? 350 : (root.isPlaying ? 230 : 190)
            height: expanded ? 104 : 36
            radius: expanded ? Tokens.rounding.large : height / 2
            color: Glass.sheet
            clip: true

            Behavior on width {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on height {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on radius {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            GlassGrain {
                grainOpacity: 0.025
            }

            GlassBevel {
                radius: islandCapsule.radius
            }

            Timer {
                id: collapseTimer

                interval: 4000
                onTriggered: islandCapsule.expanded = false
            }

            // Compact Pill View
            Item {
                id: compactView

                anchors.fill: parent
                visible: opacity > 0
                opacity: islandCapsule.expanded ? 0 : 1

                Behavior on opacity {
                    Anim {
                        duration: 140
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    // Mini pulsating/rotating note icon
                    MaterialIcon {
                        text: "music_note"
                        color: Colours.palette.m3primary
                        font.pointSize: 14
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Mini Equalizer Bars
                    Row {
                        id: eqRow

                        property real tick: 0

                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        Timer {
                            interval: 120
                            running: root.isPlaying && !islandCapsule.expanded
                            repeat: true
                            onTriggered: eqRow.tick = (eqRow.tick + 1) % 100
                        }

                        Repeater {
                            model: 3

                            Rectangle {
                                required property int index

                                width: 3
                                height: root.isPlaying ? (4 + ((Math.sin(eqRow.tick * 0.5 + index * 1.6) + 1) * 5)) : 3
                                radius: 1.5
                                color: Colours.palette.m3primary
                                anchors.bottom: parent.bottom

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }
                            }
                        }
                    }

                    // Marquee / Track Title
                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: root.player?.trackTitle || Tr.tr("Playing")
                        elide: Text.ElideRight
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.small
                    }

                    // Play/Pause toggle button
                    MaterialIcon {
                        text: root.isPlaying ? "pause" : "play_arrow"
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: 15
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.player?.playPause()
                        }
                    }
                }
            }

            // Expanded Card View
            Item {
                id: expandedView

                anchors.fill: parent
                anchors.margins: 12
                visible: opacity > 0
                opacity: islandCapsule.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {
                        duration: 140
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Album art thumbnail
                        Rectangle {
                            width: 44
                            height: 44
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3surfaceContainerHigh
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: root.player ? Players.getArtUrl(root.player) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "album"
                                color: Colours.palette.m3onSurfaceVariant
                                visible: !parent.children[0].source
                            }
                        }

                        // Track Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.player?.trackTitle || Tr.tr("Unknown Title")
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.title.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.player?.trackArtist || root.player?.identity || Tr.tr("Unknown Artist")
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                            }
                        }

                        // Control Buttons
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                text: "skip_previous"
                                color: Colours.palette.m3onSurface
                                font.pointSize: 18

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.player?.previous();
                                        collapseTimer.restart();
                                    }
                                }
                            }

                            MaterialIcon {
                                text: root.isPlaying ? "pause_circle" : "play_circle"
                                color: Colours.palette.m3primary
                                font.pointSize: 22

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.player?.playPause();
                                        collapseTimer.restart();
                                    }
                                }
                            }

                            MaterialIcon {
                                text: "skip_next"
                                color: Colours.palette.m3onSurface
                                font.pointSize: 18

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.player?.next();
                                        collapseTimer.restart();
                                    }
                                }
                            }
                        }
                    }

                    // Progress / scrubber track
                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.15)

                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: Colours.palette.m3primary
                            width: root.player && root.player.length > 0 ? parent.width * Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    islandCapsule.expanded = !islandCapsule.expanded;
                    if (islandCapsule.expanded)
                        collapseTimer.restart();
                    else
                        collapseTimer.stop();
                }
            }
        }
    }
}
