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

    readonly property bool hasNotifs: Notifs.notClosed.length > 0

    cardId: "notifications"
    title: Tr.tr("Notification Center")
    minW: 320
    minH: root.hasNotifs ? 110 : 54
    defaultH: root.hasNotifs ? 136 : 60
    canResize: true
    contentPadding: 14

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header Row / Micro-Banner
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: Tokens.rounding.small
                color: Glass.frost
                border.width: 1
                border.color: Glass.rim

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

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.hasNotifs ? "notifications" : "done_all"
                    color: Glass.ice
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: root.hasNotifs ? Tr.tr("Notifications") : Tr.tr("All Caught Up")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Glass.ice
                Layout.fillWidth: true
            }

            // Tactile Unread Count Pill Badge
            Rectangle {
                implicitWidth: badgeText.implicitWidth + 12
                implicitHeight: 20
                radius: Tokens.rounding.full
                visible: root.hasNotifs
                color: Glass.frost
                border.width: 1
                border.color: Glass.rim

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: `${Notifs.notClosed.length}`
                    font: Tokens.font.label.small
                    color: Glass.ice
                }
            }

            // Subtitle when empty
            StyledText {
                text: Tr.tr("No alerts")
                font: Tokens.font.label.small
                color: Glass.haze
                visible: !root.hasNotifs
            }

            // Clear All Button (Tactile Inset Micro-Button)
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: Tokens.rounding.small
                visible: root.hasNotifs
                color: clearMouse.pressed ? Glass.frostHigh : (clearMouse.containsMouse ? Glass.frostHigh : Glass.frost)
                border.width: 1
                border.color: clearMouse.containsMouse ? Glass.ice : Glass.rim
                scale: clearMouse.pressed ? 0.92 : (clearMouse.containsMouse ? 1.05 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "clear_all"
                    color: clearMouse.containsMouse ? Glass.ice : Glass.haze
                    fontStyle: Tokens.font.icon.small
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
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
                    radius: Tokens.rounding.medium
                    color: itemHover.hovered ? Glass.frostHigh : Glass.frost
                    border.width: 1
                    border.color: itemHover.hovered ? Glass.ice : Glass.rim

                    // Top-lit specular hairline
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

                    HoverHandler {
                        id: itemHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // Recessed App Icon Well
                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Tokens.rounding.small
                            color: Glass.well
                            border.width: 1
                            border.color: Glass.rim

                            Image {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: (notifItem.n?.appIcon && Quickshell.iconPath(notifItem.n.appIcon, true)) || notifItem.n?.appIcon || ""
                                sourceSize.width: 18
                                sourceSize.height: 18
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "notifications"
                                color: Glass.ice
                                fontStyle: Tokens.font.icon.small
                                visible: !notifItem.n?.appIcon
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
                                    color: Glass.ice
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: notifItem.n?.time ? Qt.formatTime(new Date(notifItem.n.time), "hh:mm") : ""
                                    font: Tokens.font.label.small
                                    color: Glass.haze
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: notifItem.n?.summary || ""
                                font: Tokens.font.label.small
                                color: Glass.ice
                                elide: Text.ElideRight
                            }
                        }

                        // Dismiss button
                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: Tokens.rounding.small
                            color: closeHover.hovered ? Glass.frostHigh : "transparent"

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: closeHover.hovered ? Glass.ice : Glass.haze
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
            radius: Tokens.rounding.medium
            color: Glass.well
            border.width: 1
            border.color: Glass.rim

            Row {
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "check_circle"
                    color: Glass.haze
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.tr("No pending notifications")
                    font: Tokens.font.label.small
                    color: Glass.haze
                }
            }
        }
    }
}
