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
                    text: "mail"
                    color: Glass.ice
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Primary Mails")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Glass.ice
                Layout.fillWidth: true
            }

            // Tactile Unread Pill Badge (Glass.frost + Glass.ice Glow)
            Rectangle {
                implicitWidth: unreadText.implicitWidth + 12
                implicitHeight: 20
                radius: Tokens.rounding.full
                color: MailService.unreadCount > 0 ? Glass.frostHigh : Glass.well
                border.width: 1
                border.color: MailService.unreadCount > 0 ? Glass.ice : Glass.rim

                StyledText {
                    id: unreadText
                    anchors.centerIn: parent
                    text: `${MailService.unreadCount} unread`
                    font: Tokens.font.label.small
                    color: MailService.unreadCount > 0 ? Glass.ice : Glass.haze
                }
            }

            // Tactile Refresh Button
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: Tokens.rounding.small
                color: refreshMouse.pressed ? Glass.frostHigh : (refreshHover.hovered ? Glass.frostHigh : Glass.frost)
                border.width: 1
                border.color: Glass.rim
                scale: refreshMouse.pressed ? 0.94 : 1.0

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "refresh"
                    color: Glass.ice
                    fontStyle: Tokens.font.icon.small
                }

                HoverHandler {
                    id: refreshHover
                }

                MouseArea {
                    id: refreshMouse
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
                    radius: Tokens.rounding.medium
                    color: mailHover.hovered ? Glass.frostHigh : (mailItem.m?.unread ? Glass.frost : Glass.mistHigh)
                    border.width: 1
                    border.color: mailHover.hovered ? Glass.ice : (mailItem.m?.unread ? Qt.rgba(1, 1, 1, 0.30) : Glass.rim)

                    // Top-lit bevel specular hairline
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
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Tokens.rounding.small
                            color: mailItem.m?.unread ? Glass.frost : Glass.well
                            border.width: 1
                            border.color: Glass.rim

                            StyledText {
                                anchors.centerIn: parent
                                text: (mailItem.m?.sender ?? "M").charAt(0).toUpperCase()
                                font: Tokens.font.label.small
                                color: Glass.ice
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
                                    color: Glass.ice
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: mailItem.m?.time || ""
                                    font: Tokens.font.label.small
                                    color: Glass.haze
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: mailItem.m?.subject || ""
                                font: Tokens.font.label.small
                                color: mailItem.m?.unread ? Glass.ice : Glass.haze
                                elide: Text.ElideRight
                            }
                        }

                        // Glowing Unread Dot
                        Rectangle {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: Glass.ice
                            visible: mailItem.m?.unread ?? false
                        }
                    }
                }
            }
        }

        // Fixed Footer Action Launchers: Tactile Pill Bevels (Glass.frost + scale 0.96)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Open in Brave (Gmail) Tactile Pill Button
            Rectangle {
                id: gmailBtn
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: gmailMouse.pressed ? Glass.frostHigh : (gmailHover.hovered ? Glass.frostHigh : Glass.frost)
                border.width: 1
                border.color: Glass.rim
                scale: gmailMouse.pressed ? 0.96 : 1.0

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                // Top-lit bevel specular hairline
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Glass.ice
                    opacity: 0.35
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "open_in_browser"
                        color: Glass.ice
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Gmail"
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: Glass.ice
                    }
                }

                HoverHandler {
                    id: gmailHover
                }

                MouseArea {
                    id: gmailMouse
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
                radius: Tokens.rounding.full
                color: tbMouse.pressed ? Glass.frostHigh : (tbHover.hovered ? Glass.frostHigh : Glass.frost)
                border.width: 1
                border.color: Glass.rim
                scale: tbMouse.pressed ? 0.96 : 1.0

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                // Top-lit bevel specular hairline
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Glass.ice
                    opacity: 0.35
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "mail"
                        color: Glass.ice
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Thunderbird"
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: Glass.ice
                    }
                }

                HoverHandler {
                    id: tbHover
                }

                MouseArea {
                    id: tbMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MailService.openClient("thunderbird")
                }
            }
        }
    }
}
