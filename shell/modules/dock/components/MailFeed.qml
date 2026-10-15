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

    cardId: "mail"
    title: Tr.tr("Mail Feed")
    minW: 320
    minH: 180
    canResize: true
    contentPadding: 16

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 22
                implicitHeight: 22
                radius: 6
                color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.15)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "mail"
                    color: "#c084fc"
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Primary Mails")
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: Qt.rgba(1, 1, 1, 0.95)
                Layout.fillWidth: true
            }

            // Unread Badge
            Rectangle {
                implicitWidth: unreadText.implicitWidth + 8
                implicitHeight: 18
                radius: 6
                color: MailService.unreadCount > 0 ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.20) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: MailService.unreadCount > 0 ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.35) : Qt.rgba(255, 255, 255, 0.06)

                StyledText {
                    id: unreadText
                    anchors.centerIn: parent
                    text: `${MailService.unreadCount} unread`
                    font: Tokens.font.label.small
                    color: MailService.unreadCount > 0 ? "#c084fc" : Qt.rgba(1, 1, 1, 0.50)
                }
            }

            // Refresh button
            Rectangle {
                implicitWidth: 20
                implicitHeight: 20
                radius: 4
                color: refreshHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "refresh"
                    color: Qt.rgba(1, 1, 1, 0.50)
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

        // Body: Scrollable Email List
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                anchors.fill: parent
                model: MailService.emails
                clip: true
                spacing: 4

                delegate: Rectangle {
                    id: mailItem

                    required property var modelData
                    readonly property var m: modelData

                    width: ListView.view.width
                    implicitHeight: 44
                    radius: 8
                    color: mailHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : (mailItem.m?.unread ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                    border.width: 1
                    border.color: mailItem.m?.unread ? Qt.rgba(255, 255, 255, 0.06) : "transparent"

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

                        // Initial Avatar
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 6
                            color: mailItem.m?.unread ? "#c084fc" : Qt.rgba(1, 1, 1, 0.08)

                            StyledText {
                                anchors.centerIn: parent
                                text: (mailItem.m?.sender ?? "M").charAt(0).toUpperCase()
                                font: Tokens.font.label.small
                                color: mailItem.m?.unread ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60)
                            }
                        }

                        // Mail Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 4

                                StyledText {
                                    text: mailItem.m?.sender || "Sender"
                                    font: mailItem.m?.unread ? Tokens.font.body.builders.small.weight(Font.DemiBold).build() : Tokens.font.label.small
                                    color: Qt.rgba(1, 1, 1, 0.95)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: mailItem.m?.time || ""
                                    font: Tokens.font.label.small
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: mailItem.m?.subject || ""
                                font: Tokens.font.label.small
                                color: mailItem.m?.unread ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.50)
                                elide: Text.ElideRight
                            }
                        }

                        // Unread Dot
                        Rectangle {
                            implicitWidth: 5
                            implicitHeight: 5
                            radius: 2.5
                            color: "#c084fc"
                            visible: mailItem.m?.unread ?? false
                        }
                    }
                }
            }
        }

        // Fixed Footer Action Launchers: Exactly 30px height, zero crushing
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 8

            // Open in Brave (Gmail)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: gmailHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "open_in_browser"
                        color: Qt.rgba(1, 1, 1, 0.80)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Gmail"
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.90)
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
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: tbHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "mail"
                        color: Qt.rgba(1, 1, 1, 0.80)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Thunderbird"
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.90)
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
