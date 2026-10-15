pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils

StyledRect {
    id: root

    color: Glass.enabled ? Glass.mist : Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge
    implicitHeight: 180

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 26
                implicitHeight: 26
                radius: Tokens.rounding.medium
                color: Qt.alpha(Colours.palette.m3primary, Glass.enabled ? 0.25 : 0.15)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "notifications"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Live Notifications")
                font: Tokens.font.title.small
                color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                Layout.fillWidth: true
            }

            // Notification Count Badge
            StyledRect {
                implicitWidth: badgeText.implicitWidth + 12
                implicitHeight: 20
                radius: 10
                color: Notifs.notClosed.length > 0 ? Colours.palette.m3errorContainer : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHighest)

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: `${Notifs.notClosed.length}`
                    font: Tokens.font.label.small
                    color: Notifs.notClosed.length > 0 ? Colours.palette.m3onErrorContainer : (Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant)
                }
            }

            // Clear All Button (if any)
            StyledRect {
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                visible: Notifs.notClosed.length > 0
                color: clearHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "clear_all"
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurfaceVariant
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

        // Body: List or Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty State
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                visible: Notifs.notClosed.length === 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "done_all"
                    color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("All caught up!")
                    font: Tokens.font.body.small
                    color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                }
            }

            // Notification Items List
            ListView {
                anchors.fill: parent
                model: Notifs.notClosed
                clip: true
                spacing: 6
                visible: Notifs.notClosed.length > 0

                delegate: StyledRect {
                    id: notifItem

                    required property var modelData
                    readonly property var n: modelData

                    width: ListView.view.width
                    implicitHeight: 46
                    radius: Tokens.rounding.medium
                    color: itemHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh)

                    HoverHandler {
                        id: itemHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        // App Icon
                        StyledRect {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Tokens.rounding.medium
                            color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainer

                            Loader {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                active: (notifItem.n?.appIcon ?? "") !== ""
                                sourceComponent: Image {
                                    source: Quickshell.iconPath(notifItem.n?.appIcon, true) || notifItem.n?.appIcon || ""
                                    sourceSize.width: 20
                                    sourceSize.height: 20
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Loader {
                                anchors.centerIn: parent
                                active: !notifItem.n?.appIcon
                                sourceComponent: MaterialIcon {
                                    text: "notifications"
                                    color: Colours.palette.m3primary
                                    fontStyle: Tokens.font.icon.small
                                }
                            }
                        }

                        // Text content
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 4

                                StyledText {
                                    text: notifItem.n?.appName || Tr.tr("Notification")
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3primary
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: notifItem.n?.time ? Qt.formatTime(new Date(notifItem.n.time), "hh:mm") : ""
                                    font: Tokens.font.label.small
                                    color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: notifItem.n?.summary || ""
                                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                                color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }
                        }

                        // Dismiss button
                        StyledRect {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: closeHover.hovered ? Colours.palette.m3errorContainer : "transparent"

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: closeHover.hovered ? Colours.palette.m3onErrorContainer : (Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant)
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
