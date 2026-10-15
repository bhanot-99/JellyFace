pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.images
import qs.services
import qs.utils
import ".."

ModularCard {
    id: root

    cardId: "profile"
    title: Tr.tr("Profile Status")
    minW: 320
    minH: 88
    canResize: true
    contentPadding: 16

    RowLayout {
        anchors.fill: parent
        spacing: 14

        // Avatar: 48x48px with Hairline Rim
        Item {
            implicitWidth: 48
            implicitHeight: 48
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 24
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.15)
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
                        color: Qt.rgba(1, 1, 1, 0.85)
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }

            // Edit icon hint on hover
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: Colours.palette.m3primary
                visible: avatarHover.hovered

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "edit"
                    color: "#ffffff"
                    fontStyle: Tokens.font.icon.small
                }
            }

            HoverHandler {
                id: avatarHover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["notify-send", "-a", "jellyface", "Profile", "To set your avatar, save a picture as ~/.face or ~/.face.icon"])
            }
        }

        // User Info & Badges
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            RowLayout {
                spacing: 6

                StyledText {
                    text: SysInfo.user || "User"
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Qt.rgba(1, 1, 1, 0.95)
                    elide: Text.ElideRight
                }

                // Ambient Emerald "Active" Badge
                Rectangle {
                    implicitWidth: onlineDot.implicitWidth + 8
                    implicitHeight: 18
                    radius: 6
                    color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.25)

                    Row {
                        id: onlineDot
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 5
                            radius: 2.5
                            color: "#34d399"
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Active"
                            font: Tokens.font.label.small
                            color: "#34d399"
                        }
                    }
                }
            }

            StyledText {
                text: `@${SysInfo.hostname || "pop-os"}`
                font: Tokens.font.label.small
                color: Qt.rgba(1, 1, 1, 0.50)
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 8

                // OS Chip
                Row {
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "laptop_chromebook"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.50)
                    }
                }

                // Uptime Chip
                Row {
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "schedule"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Up ${SysInfo.uptimeShort || "1h"}`
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.50)
                    }
                }
            }
        }
    }
}
