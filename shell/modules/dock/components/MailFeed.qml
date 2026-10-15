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
        spacing: 10

        // Header
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
                    text: "mail"
                    color: "#FFFFFF"
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Primary Mails")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: "#FFFFFF"
                Layout.fillWidth: true
            }

            // Tactile Unread Pill Badge (Pure White Glow)
            Rectangle {
                implicitWidth: unreadText.implicitWidth + 12
                implicitHeight: 20
                radius: 9999
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: MailService.unreadCount > 0 ? "#444852" : "#1b1c20"
                    }
                    GradientStop {
                        position: 1.0
                        color: MailService.unreadCount > 0 ? "#31343b" : "#24262b"
                    }
                }
                border.width: 1
                border.color: MailService.unreadCount > 0 ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.08)

                StyledText {
                    id: unreadText
                    anchors.centerIn: parent
                    text: `${MailService.unreadCount} unread`
                    font: Tokens.font.label.small
                    color: MailService.unreadCount > 0 ? "#FFFFFF" : "#9CA3AF"
                }
            }

            // Tactile Refresh Button
            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 8
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: refreshHover.hovered ? "#4f5460" : "#373a42"
                    }
                    GradientStop {
                        position: 1.0
                        color: refreshHover.hovered ? "#383b44" : "#26282e"
                    }
                }
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.12)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "refresh"
                    color: "#E5E7EB"
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

        // Body: Scrollable Email List with Segmented Tactile Cards
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                anchors.fill: parent
                model: MailService.emails
                clip: true
                spacing: 6

                delegate: Rectangle {
                    id: mailItem

                    required property var modelData
                    readonly property var m: modelData

                    width: ListView.view.width
                    implicitHeight: 48
                    radius: 12
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: mailHover.hovered ? "#4a4e58" : (mailItem.m?.unread ? "#3d4047" : "#2e3137")
                        }
                        GradientStop {
                            position: 1.0
                            color: mailHover.hovered ? "#353840" : (mailItem.m?.unread ? "#2a2c32" : "#222428")
                        }
                    }
                    border.width: 1
                    border.color: mailHover.hovered ? Qt.rgba(255, 255, 255, 0.22) : (mailItem.m?.unread ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05))

                    // Top-lit bevel specular hairline
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
                        anchors.margins: 8
                        spacing: 10

                        // Recessed Avatar Well
                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: mailItem.m?.unread ? "#444852" : "#1b1c20"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: mailItem.m?.unread ? "#31343b" : "#24262b"
                                }
                            }
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            StyledText {
                                anchors.centerIn: parent
                                text: (mailItem.m?.sender ?? "M").charAt(0).toUpperCase()
                                font: Tokens.font.label.small
                                color: "#FFFFFF"
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
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: mailItem.m?.time || ""
                                    font: Tokens.font.label.small
                                    color: "#6B7280"
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: mailItem.m?.subject || ""
                                font: Tokens.font.label.small
                                color: mailItem.m?.unread ? "#E5E7EB" : "#9CA3AF"
                                elide: Text.ElideRight
                            }
                        }

                        // Pure White Glowing Unread Dot
                        Rectangle {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: "#FFFFFF"
                            visible: mailItem.m?.unread ?? false
                        }
                    }
                }
            }
        }

        // Fixed Footer Action Launchers: Tactile Pill Bevels (Matching Image 2 footer)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Open in Brave (Gmail) Tactile Pill Button
            Rectangle {
                id: gmailBtn
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 9999
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: gmailHover.hovered ? "#4f5460" : "#444852"
                    }
                    GradientStop {
                        position: 1.0
                        color: gmailHover.hovered ? "#383b44" : "#31343b"
                    }
                }
                border.width: 1
                border.color: gmailHover.hovered ? Qt.rgba(255, 255, 255, 0.30) : Qt.rgba(255, 255, 255, 0.14)

                // Top-lit bevel specular hairline
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.28)
                }

                // Bottom recessed shadow hairline
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(0, 0, 0, 0.40)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "open_in_browser"
                        color: "#FFFFFF"
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Gmail"
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: "#FFFFFF"
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

            // Launch Thunderbird Tactile Pill Button
            Rectangle {
                id: tbBtn
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 9999
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: tbHover.hovered ? "#4f5460" : "#444852"
                    }
                    GradientStop {
                        position: 1.0
                        color: tbHover.hovered ? "#383b44" : "#31343b"
                    }
                }
                border.width: 1
                border.color: tbHover.hovered ? Qt.rgba(255, 255, 255, 0.30) : Qt.rgba(255, 255, 255, 0.14)

                // Top-lit bevel specular hairline
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.28)
                }

                // Bottom recessed shadow hairline
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(0, 0, 0, 0.40)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "mail"
                        color: "#FFFFFF"
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Thunderbird"
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: "#FFFFFF"
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
