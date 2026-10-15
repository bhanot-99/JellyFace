pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils

Rectangle {
    id: root

    readonly property bool hasNotifs: Notifs.notClosed.length > 0

    color: Qt.rgba(1, 1, 1, 0.04)
    radius: 16
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.06)

    // Purpose-built adaptive height: sleek micro-banner when empty, expanded list when notifications exist
    implicitHeight: root.hasNotifs ? 140 : 44
    Layout.minimumHeight: root.hasNotifs ? 120 : 44
    Layout.preferredHeight: root.hasNotifs ? 140 : 44

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Header Row / Micro-Banner
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 22
                implicitHeight: 22
                radius: 6
                color: root.hasNotifs ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.15) : Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.15)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.hasNotifs ? "notifications" : "done_all"
                    color: root.hasNotifs ? "#f87171" : "#34d399"
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: root.hasNotifs ? Tr.tr("Live Notifications") : Tr.tr("All caught up")
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: Qt.rgba(1, 1, 1, 0.95)
                Layout.fillWidth: true
            }

            // Notification Count Badge (if any)
            Rectangle {
                implicitWidth: badgeText.implicitWidth + 8
                implicitHeight: 18
                radius: 6
                visible: root.hasNotifs
                color: Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.20)
                border.width: 1
                border.color: Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.35)

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: `${Notifs.notClosed.length}`
                    font: Tokens.font.label.small
                    color: "#f87171"
                }
            }

            // Subtitle when empty
            StyledText {
                text: "No new notifications"
                font: Tokens.font.label.small
                color: Qt.rgba(1, 1, 1, 0.40)
                visible: !root.hasNotifs
            }

            // Clear All Button (when notifications exist)
            Rectangle {
                implicitWidth: 20
                implicitHeight: 20
                radius: 4
                visible: root.hasNotifs
                color: clearHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "clear_all"
                    color: Qt.rgba(1, 1, 1, 0.60)
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

        // Notification List (only visible when notifications exist)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.hasNotifs

            ListView {
                anchors.fill: parent
                model: Notifs.notClosed
                clip: true
                spacing: 4

                delegate: Rectangle {
                    id: notifItem

                    required property var modelData
                    readonly property var n: modelData

                    width: ListView.view.width
                    implicitHeight: 38
                    radius: 8
                    color: itemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.04)

                    HoverHandler {
                        id: itemHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.06)

                            Loader {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                active: (notifItem.n?.appIcon ?? "") !== ""
                                sourceComponent: Image {
                                    source: Quickshell.iconPath(notifItem.n?.appIcon, true) || notifItem.n?.appIcon || ""
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Loader {
                                anchors.centerIn: parent
                                active: !notifItem.n?.appIcon
                                sourceComponent: MaterialIcon {
                                    text: "notifications"
                                    color: Qt.rgba(1, 1, 1, 0.80)
                                    fontStyle: Tokens.font.icon.small
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                spacing: 4

                                StyledText {
                                    text: notifItem.n?.appName || "Notification"
                                    font: Tokens.font.label.small
                                    color: "#38bdf8"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: notifItem.n?.time ? Qt.formatTime(new Date(notifItem.n.time), "hh:mm") : ""
                                    font: Tokens.font.label.small
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: notifItem.n?.summary || ""
                                font: Tokens.font.label.small
                                color: Qt.rgba(1, 1, 1, 0.90)
                                elide: Text.ElideRight
                            }
                        }

                        // Dismiss button
                        Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 4
                            color: closeHover.hovered ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.20) : "transparent"

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: closeHover.hovered ? "#f87171" : Qt.rgba(1, 1, 1, 0.40)
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
    }
}
