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
    implicitHeight: 210

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
                color: Qt.alpha(Colours.palette.m3secondary, Glass.enabled ? 0.25 : 0.15)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "mail"
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Primary Mails")
                font: Tokens.font.title.small
                color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                Layout.fillWidth: true
            }

            // Unread Badge
            StyledRect {
                implicitWidth: unreadText.implicitWidth + 12
                implicitHeight: 20
                radius: 10
                color: MailService.unreadCount > 0 ? Colours.palette.m3secondaryContainer : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHighest)

                StyledText {
                    id: unreadText
                    anchors.centerIn: parent
                    text: `${MailService.unreadCount} unread`
                    font: Tokens.font.label.small
                    color: MailService.unreadCount > 0 ? Colours.palette.m3onSecondaryContainer : (Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant)
                }
            }

            // Refresh button
            StyledRect {
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                color: refreshHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "refresh"
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                HoverHandler {
                    id: refreshHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MailService.refresh()
                }
            }
        }

        // Body: Email List
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                anchors.fill: parent
                model: MailService.emails
                clip: true
                spacing: 6

                delegate: StyledRect {
                    id: mailItem

                    required property var modelData
                    readonly property var m: modelData

                    width: ListView.view.width
                    implicitHeight: 46
                    radius: Tokens.rounding.medium
                    color: mailHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (mailItem.m?.unread ? (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh) : "transparent")

                    HoverHandler {
                        id: mailHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (mailItem.m?.id)
                                MailService.markRead(mailItem.m.id);
                            MailService.openGmail();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        // Initial Avatar circle
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: mailItem.m?.unread ? Colours.palette.m3primary : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHighest)

                            StyledText {
                                anchors.centerIn: parent
                                text: (mailItem.m?.sender ?? "M").charAt(0).toUpperCase()
                                font: Tokens.font.label.small
                                color: mailItem.m?.unread ? Colours.palette.m3onPrimary : (Glass.enabled ? Glass.hazeHigh : Colours.palette.m3onSurfaceVariant)
                            }
                        }

                        // Mail info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 4

                                StyledText {
                                    text: mailItem.m?.sender || "Sender"
                                    font: mailItem.m?.unread ? Tokens.font.body.builders.small.weight(Font.Bold).build() : Tokens.font.body.small
                                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: mailItem.m?.time || ""
                                    font: Tokens.font.label.small
                                    color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: mailItem.m?.subject || ""
                                font: Tokens.font.body.small
                                color: mailItem.m?.unread ? (Glass.enabled ? Glass.ice : Colours.palette.m3onSurface) : (Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant)
                                elide: Text.ElideRight
                            }
                        }

                        // Unread dot
                        Rectangle {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: Colours.palette.m3primary
                            visible: mailItem.m?.unread ?? false
                        }
                    }
                }
            }
        }

        // Quick Client Launchers
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Open in Brave (Gmail)
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Tokens.rounding.full
                color: gmailHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh)

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "open_in_browser"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Gmail (Brave)"
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                    }
                }

                HoverHandler {
                    id: gmailHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MailService.openGmail()
                }
            }

            // Launch Thunderbird
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Tokens.rounding.full
                color: tbHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh)

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "mail"
                        color: Colours.palette.m3secondary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Thunderbird"
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                    }
                }

                HoverHandler {
                    id: tbHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MailService.openClient("thunderbird")
                }
            }
        }
    }
}
