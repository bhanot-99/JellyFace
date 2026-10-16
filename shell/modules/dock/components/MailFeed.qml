pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
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
    contentPadding: 14

    function cleanLine(str: var): string {
        if (!str) return "";
        return ("" + str).replace(/[\r\n\t]+/g, " ").replace(/\s{2,}/g, " ").trim();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // 1. Header (Fixed Height)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Card / Mail Icon
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: Tokens.rounding.small
                color: Glass.glassElevatedTile
                border.width: 1
                border.color: Glass.glassBorder

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "mail"
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Primary Mails")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Glass.textPrimary
                Layout.fillWidth: true
            }

            // Tactile Unread Pill Badge
            Rectangle {
                implicitWidth: unreadText.implicitWidth + 12
                implicitHeight: 20
                radius: Tokens.rounding.full
                color: MailService.unreadCount > 0 ? Glass.glassActivePill : Glass.glassRecessedWell
                border.width: 1
                border.color: MailService.unreadCount > 0 ? Glass.glassActivePill : Glass.glassBorder

                StyledText {
                    id: unreadText
                    anchors.centerIn: parent
                    text: `${MailService.unreadCount} unread`
                    font: Tokens.font.label.small
                    color: MailService.unreadCount > 0 ? Glass.textDark : Glass.textMuted
                }
            }

            // Tactile Refresh / Gmail Sync Button
            Rectangle {
                id: refreshBtn
                implicitWidth: 26
                implicitHeight: 26
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                z: 20
                radius: Tokens.rounding.small
                color: refreshMouse.pressed ? Glass.glassActivePill : (refreshMouse.containsMouse ? Glass.glassPillHover : Glass.glassElevatedTile)
                border.width: 1
                border.color: refreshMouse.containsMouse || MailService.isSyncing ? Glass.glassActivePill : Glass.glassBorder
                scale: refreshMouse.pressed ? 0.92 : (refreshMouse.containsMouse ? 1.05 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on border.color {
                    CAnim {
                        duration: 150
                    }
                }

                Behavior on color {
                    CAnim {
                        duration: 150
                    }
                }

                MaterialIcon {
                    id: refreshIcon
                    anchors.centerIn: parent
                    text: "refresh"
                    color: refreshMouse.pressed ? Glass.textDark : (MailService.isSyncing || refreshMouse.containsMouse ? Glass.textPrimary : Glass.textSecondary)
                    fontStyle: Tokens.font.icon.small

                    RotationAnimation on rotation {
                        running: MailService.isSyncing
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 750
                    }
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: {
                        console.info("MailFeed: Refresh button clicked!");
                        MailService.refresh();
                    }
                }
            }
        }

        // 2. Scrollable Dynamic Feed (Fills all remaining height)
        ListView {
            id: mailListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: vbar
                policy: Controls.ScrollBar.AsNeeded
                width: 4

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Glass.textPrimary
                    opacity: vbar.pressed ? 0.65 : (vbar.hovered ? 0.45 : 0.25)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }

            model: MailService.emails

            // Empty State Placeholder
            Item {
                anchors.fill: parent
                visible: MailService.emails.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "mark_email_read"
                        color: Glass.textMuted
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("No Recent Emails")
                        font: Tokens.font.label.medium
                        color: Glass.textMuted
                    }
                }
            }

            delegate: Rectangle {
                id: mailItem

                required property var modelData
                readonly property var m: modelData

                width: ListView.view.width
                implicitHeight: Math.max(52, mailContentRow.implicitHeight + 16)
                radius: Tokens.rounding.medium
                color: mailMouse.containsMouse ? Glass.glassPillHover : (mailItem.m?.unread ? Glass.glassElevatedTile : (Glass.enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.10) : Colours.palette.m3surfaceContainerLow))
                border.width: 1
                border.color: mailMouse.containsMouse ? Glass.glassBorderHover : (mailItem.m?.unread ? Glass.glassBorderHover : Glass.glassBorder)

                Behavior on color {
                    CAnim {
                        duration: 150
                    }
                }
                Behavior on border.color {
                    CAnim {
                        duration: 150
                    }
                }

                MouseArea {
                    id: mailMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (mailItem.m?.id)
                            MailService.markRead(mailItem.m.id);
                        MailService.openGmail();
                    }
                }

                RowLayout {
                    id: mailContentRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // Recessed Avatar Well
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        radius: Tokens.rounding.small
                        color: mailItem.m?.unread ? Glass.glassElevatedTile : Glass.glassRecessedWell
                        border.width: 1
                        border.color: mailItem.m?.unread ? Glass.glassRimTop : Glass.glassRimBottom

                        StyledText {
                            anchors.centerIn: parent
                            text: (mailItem.m?.sender ?? "M").charAt(0).toUpperCase()
                            font: Tokens.font.label.small
                            color: mailItem.m?.unread ? Glass.textPrimary : Glass.textSecondary
                        }
                    }

                    // Mail Info Column
                    ColumnLayout {
                        id: mailContentColumn
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        // Top Row: Sender (left) & Timestamp (right)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                text: root.cleanLine(mailItem.m?.sender || "Sender")
                                font: mailItem.m?.unread ? Tokens.font.body.builders.small.weight(Font.DemiBold).build() : Tokens.font.label.small
                                color: Glass.textPrimary
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: mailItem.m?.time || ""
                                font: Tokens.font.label.small
                                color: Glass.textMuted
                                Layout.alignment: Qt.AlignRight
                            }
                        }

                        // Middle Row: Subject
                        StyledText {
                            Layout.fillWidth: true
                            text: root.cleanLine(mailItem.m?.subject || "(No Subject)")
                            font: Tokens.font.label.small
                            color: mailItem.m?.unread ? Glass.textPrimary : Glass.textSecondary
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Snippet line (shows preview if different from subject)
                        StyledText {
                            id: snippetText
                            Layout.fillWidth: true
                            text: root.cleanLine(mailItem.m?.preview || "")
                            visible: text.length > 0 && text !== root.cleanLine(mailItem.m?.subject || "")
                            font.pixelSize: 11
                            color: Glass.textMuted
                            opacity: 0.85
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Glowing Unread Dot
                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: Glass.glassActivePill
                        visible: mailItem.m?.unread ?? false
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 2
                    }
                }
            }
        }

        // 3. Footer Action Keys (Fixed Height, Stays Pinned to Bottom)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 10

            // Open in Brave (Gmail) Tactile Pill Button
            Rectangle {
                id: gmailBtn
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Tokens.rounding.full
                color: gmailMouse.pressed ? Glass.glassActivePill : (gmailMouse.containsMouse ? Glass.glassPillHover : Glass.glassElevatedTile)
                border.width: 1
                border.color: gmailMouse.containsMouse ? Glass.glassActivePill : Glass.glassBorder
                scale: gmailMouse.pressed ? 0.96 : (gmailMouse.containsMouse ? 1.02 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }
                Behavior on border.color {
                    CAnim {
                        duration: 150
                    }
                }
                Behavior on color {
                    CAnim {
                        duration: 150
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "open_in_browser"
                        color: gmailMouse.pressed ? Glass.textDark : (gmailMouse.containsMouse ? Glass.textPrimary : Glass.textSecondary)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Gmail"
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: gmailMouse.pressed ? Glass.textDark : (gmailMouse.containsMouse ? Glass.textPrimary : Glass.textSecondary)
                    }
                }

                MouseArea {
                    id: gmailMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MailService.openGmail()
                }
            }

            // Launch Thunderbird Tactile Pill Button
            Rectangle {
                id: tbBtn
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Tokens.rounding.full
                color: tbMouse.pressed ? Glass.glassActivePill : (tbMouse.containsMouse ? Glass.glassPillHover : Glass.glassElevatedTile)
                border.width: 1
                border.color: tbMouse.containsMouse ? Glass.glassActivePill : Glass.glassBorder
                scale: tbMouse.pressed ? 0.96 : (tbMouse.containsMouse ? 1.02 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }
                Behavior on border.color {
                    CAnim {
                        duration: 150
                    }
                }
                Behavior on color {
                    CAnim {
                        duration: 150
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "mail"
                        color: tbMouse.pressed ? Glass.textDark : (tbMouse.containsMouse ? Glass.textPrimary : Glass.textSecondary)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Thunderbird"
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: tbMouse.pressed ? Glass.textDark : (tbMouse.containsMouse ? Glass.textPrimary : Glass.textSecondary)
                    }
                }

                MouseArea {
                    id: tbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MailService.openClient("thunderbird")
                }
            }
        }
    }
}
