pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils
import ".."

ModularCard {
    id: root

    cardId: "notifications"
    title: Tr.tr("Notification Center")
    minW: 320
    minH: 60
    canResize: true
    contentPadding: 14

    readonly property bool hasNotifs: Notifs.notClosed.length > 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header Row / Micro-Banner
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
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
                border.color: Qt.rgba(255, 255, 255, 0.12)

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.25)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.hasNotifs ? "notifications" : "done_all"
                    color: "#FFFFFF"
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: root.hasNotifs ? Tr.tr("Notifications") : Tr.tr("All Caught Up")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: "#FFFFFF"
                Layout.fillWidth: true
            }

            // Tactile Unread Count Pill Badge
            Rectangle {
                implicitWidth: badgeText.implicitWidth + 12
                implicitHeight: 20
                radius: 9999
                visible: root.hasNotifs
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
                border.color: Qt.rgba(255, 255, 255, 0.20)

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: `${Notifs.notClosed.length}`
                    font: Tokens.font.label.small
                    color: "#FFFFFF"
                }
            }

            // Subtitle when empty
            StyledText {
                text: Tr.tr("No alerts")
                font: Tokens.font.label.small
                color: "#9CA3AF"
                visible: !root.hasNotifs
            }

            // Clear All Button (Tactile Inset Micro-Button)
            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 8
                visible: root.hasNotifs
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: clearHover.hovered ? "#3d4047" : "#1b1c20"
                    }
                    GradientStop {
                        position: 1.0
                        color: clearHover.hovered ? "#2a2c32" : "#24262b"
                    }
                }
                border.width: 1
                border.color: clearHover.hovered ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "clear_all"
                    color: "#9CA3AF"
                    fontStyle: Tokens.font.icon.small
                }

                HoverHandler {
                    id: clearHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        for (let i = 0; i < Notifs.notClosed.length; i++) {
                            const n = Notifs.notClosed[i];
                            if (n) {
                                n.notification?.dismiss();
                                n.closed = true;
                            }
                        }
                    }
                }
            }
        }

        // Notification List (Tactile Segmented Sub-Cards)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.hasNotifs

            ListView {
                anchors.fill: parent
                model: Notifs.notClosed
                clip: true
                spacing: 6

                delegate: Rectangle {
                    id: notifItem

                    required property var modelData
                    readonly property var n: modelData

                    width: ListView.view.width
                    implicitHeight: 48
                    radius: 12
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: itemHover.hovered ? "#4a4e58" : "#3d4047"
                        }
                        GradientStop {
                            position: 1.0
                            color: itemHover.hovered ? "#353840" : "#2a2c32"
                        }
                    }
                    border.width: 1
                    border.color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)

                    // Top-lit specular hairline
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: parent.radius
                        anchors.rightMargin: parent.radius
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.20)
                    }

                    HoverHandler {
                        id: itemHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // Recessed App Icon Well
                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
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
                            border.color: Qt.rgba(255, 255, 255, 0.06)

                            Loader {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                active: (notifItem.n?.appIcon ?? "") !== ""
                                sourceComponent: Image {
                                    source: Quickshell.iconPath(notifItem.n?.appIcon, true) || notifItem.n?.appIcon || ""
                                    sourceSize.width: 18
                                    sourceSize.height: 18
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Loader {
                                anchors.centerIn: parent
                                active: !notifItem.n?.appIcon
                                sourceComponent: MaterialIcon {
                                    text: "notifications"
                                    color: "#FFFFFF"
                                    fontStyle: Tokens.font.icon.small
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 6

                                StyledText {
                                    text: notifItem.n?.appName || "Alert"
                                    font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                    color: "#FFFFFF"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: notifItem.n?.time ? Qt.formatTime(new Date(notifItem.n.time), "hh:mm") : ""
                                    font: Tokens.font.label.small
                                    color: "#6B7280"
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: notifItem.n?.summary || ""
                                font: Tokens.font.label.small
                                color: "#E5E7EB"
                                elide: Text.ElideRight
                            }
                        }

                        // Dismiss button
                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 6
                            color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: closeHover.hovered ? "#FFFFFF" : "#9CA3AF"
                                fontStyle: Tokens.font.icon.small
                            }

                            HoverHandler {
                                id: closeHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (notifItem.n) {
                                        notifItem.n.notification?.dismiss();
                                        notifItem.n.closed = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Empty state banner
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hasNotifs
            radius: 12
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
            border.color: Qt.rgba(255, 255, 255, 0.06)

            Row {
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "check_circle"
                    color: "#9CA3AF"
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.tr("No pending notifications")
                    font: Tokens.font.label.small
                    color: "#9CA3AF"
                }
            }
        }
    }
}
