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

        // Avatar: 48x48px with Tactile Extruded Bezel Rim
        Item {
            implicitWidth: 48
            implicitHeight: 48
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 24
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#444852"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#26282e"
                    }
                }
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.20)
                clip: true

                // Top-lit bevel specular highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.35)
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
                        color: "#FFFFFF"
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
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#444852"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#31343b"
                    }
                }
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.25)
                visible: avatarHover.hovered

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "edit"
                    color: "#FFFFFF"
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
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                }

                // Tactile Inset "Active" Pill Badge
                Rectangle {
                    implicitWidth: onlineDot.implicitWidth + 12
                    implicitHeight: 20
                    radius: 9999
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#1b1c20"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#24262b"
                        }
                    }
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.50)
                    }

                    Row {
                        id: onlineDot
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: "#FFFFFF"
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Active"
                            font: Tokens.font.label.small
                            color: "#E5E7EB"
                        }
                    }
                }
            }

            StyledText {
                text: `@${SysInfo.hostname || "pop-os"}`
                font: Tokens.font.label.small
                color: "#9CA3AF"
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 8

                // OS Chip in Tactile Inset Pill
                Rectangle {
                    implicitWidth: osRow.implicitWidth + 12
                    implicitHeight: 22
                    radius: 9999
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#1b1c20"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#24262b"
                        }
                    }
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)

                    Row {
                        id: osRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "laptop_chromebook"
                            color: "#9CA3AF"
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                            font: Tokens.font.label.small
                            color: "#E5E7EB"
                        }
                    }
                }

                // Uptime Chip in Tactile Inset Pill
                Rectangle {
                    implicitWidth: upRow.implicitWidth + 12
                    implicitHeight: 22
                    radius: 9999
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#1b1c20"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#24262b"
                        }
                    }
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)

                    Row {
                        id: upRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "schedule"
                            color: "#9CA3AF"
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `Up ${SysInfo.uptimeShort || "1h"}`
                            font: Tokens.font.label.small
                            color: "#E5E7EB"
                        }
                    }
                }
            }
        }
    }
}
