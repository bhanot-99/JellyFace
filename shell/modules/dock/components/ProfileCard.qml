pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

StyledRect {
    id: root

    color: Glass.enabled ? Glass.mist : Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge
    implicitHeight: 120

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        // Avatar
        Item {
            implicitWidth: 64
            implicitHeight: 64
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: width / 2
                color: Glass.enabled ? Glass.frost : Colours.palette.m3secondaryContainer
                clip: true

                CachingImage {
                    id: pfp
                    anchors.fill: parent
                    path: Face.path
                }

                Loader {
                    anchors.centerIn: parent
                    active: pfp.status !== Image.Ready
                    sourceComponent: MaterialIcon {
                        text: "person"
                        color: Glass.enabled ? Glass.ice : Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.large
                    }
                }
            }

            // Small edit indicator on hover
            StyledRect {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitWidth: 20
                implicitHeight: 20
                radius: 10
                color: Colours.palette.m3primary
                visible: avatarHover.hovered

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "edit"
                    color: Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            HoverHandler {
                id: avatarHover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["notify-send", "-a", "jellyface", "Profile", "To set your avatar, save a picture as ~/.face or ~/.face.icon"]);
                }
            }
        }

        // User Info & Badges
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            RowLayout {
                spacing: 6

                StyledText {
                    text: SysInfo.user || "User"
                    font: Tokens.font.title.medium
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledRect {
                    implicitWidth: onlineDot.implicitWidth + 8
                    implicitHeight: 16
                    radius: 8
                    color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHighest

                    Row {
                        id: onlineDot
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: "#4ade80" // Active green
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Active"
                            font: Tokens.font.label.small
                            color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            StyledText {
                text: `@${SysInfo.hostname || "pop-os"}`
                font: Tokens.font.body.small
                color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 8

                // OS / Pop!_OS Badge
                Row {
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "laptop_chromebook"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.hazeHigh : Colours.palette.m3primary
                    }
                }

                // Uptime Badge
                Row {
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "schedule"
                        color: Colours.palette.m3tertiary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Up ${SysInfo.uptimeShort || "1h"}`
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
