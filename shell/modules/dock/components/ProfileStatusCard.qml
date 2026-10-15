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

        // Avatar: 48x48px with Tactile Extruded Glass Rim
        Item {
            implicitWidth: 48
            implicitHeight: 48
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 24
                color: Glass.frost
                border.width: 1
                border.color: Glass.rim
                clip: true

                // Top-lit bevel specular highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height: 1
                    color: Glass.ice
                    opacity: 0.35
                }

                CachingImage {
                    id: pfp
                    anchors.fill: parent
                    anchors.margins: 2
                    path: Face.path
                }

                Loader {
                    anchors.centerIn: parent
                    active: pfp.status !== Image.Ready
                    sourceComponent: MaterialIcon {
                        text: "person"
                        color: Glass.ice
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }

            // Edit icon hint on hover
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitWidth: 18
                implicitHeight: 18
                radius: 9
                color: Glass.frostHigh
                border.width: 1
                border.color: Glass.rim
                visible: avatarHover.hovered

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "edit"
                    color: Glass.ice
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
            spacing: 5

            RowLayout {
                spacing: 8

                StyledText {
                    text: SysInfo.user || "User"
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Glass.ice
                    elide: Text.ElideRight
                }

                // Tactile Glass Inset "Active" Pill Badge
                Rectangle {
                    implicitWidth: onlineDot.implicitWidth + 12
                    implicitHeight: 20
                    radius: Tokens.rounding.full
                    color: Glass.well
                    border.width: 1
                    border.color: Glass.rim

                    Row {
                        id: onlineDot
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Glass.ice
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Active"
                            font: Tokens.font.label.small
                            color: Glass.ice
                        }
                    }
                }
            }

            StyledText {
                text: `@${SysInfo.hostname || "pop-os"}`
                font: Tokens.font.label.small
                color: Glass.haze
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 8

                // OS Chip in Tactile Glass Inset Pill
                Rectangle {
                    implicitWidth: osRow.implicitWidth + 12
                    implicitHeight: 22
                    radius: Tokens.rounding.full
                    color: Glass.well
                    border.width: 1
                    border.color: Glass.rim

                    Row {
                        id: osRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "laptop_chromebook"
                            color: Glass.haze
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                            font: Tokens.font.label.small
                            color: Glass.ice
                        }
                    }
                }

                // Uptime Chip in Tactile Glass Inset Pill
                Rectangle {
                    implicitWidth: upRow.implicitWidth + 12
                    implicitHeight: 22
                    radius: Tokens.rounding.full
                    color: Glass.well
                    border.width: 1
                    border.color: Glass.rim

                    Row {
                        id: upRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "schedule"
                            color: Glass.haze
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `Up ${SysInfo.uptimeShort || "1h"}`
                            font: Tokens.font.label.small
                            color: Glass.ice
                        }
                    }
                }
            }
        }
    }
}
