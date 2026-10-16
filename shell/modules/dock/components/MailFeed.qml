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
    minH: 140
    canResize: true
    contentPadding: 14

    readonly property var unreadMails: (MailService.emails || []).filter(e => !!e.unread)

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
                border.width: 0

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
                color: root.unreadMails.length > 0 ? Glass.glassActivePill : Glass.glassRecessedWell
                border.width: 0

                StyledText {
                    id: unreadText
                    anchors.centerIn: parent
                    text: `${root.unreadMails.length} unread`
                    font: Tokens.font.label.small
                    color: root.unreadMails.length > 0 ? Glass.textDark : Glass.textMuted
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
                border.width: 0
                scale: refreshMouse.pressed ? 0.92 : (refreshMouse.containsMouse ? 1.05 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
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

            model: root.unreadMails

            // Empty State Placeholder
            Item {
                anchors.fill: parent
                visible: root.unreadMails.length === 0

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
                        text: Tr.tr("No Unread Emails")
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
                border.width: 0

                Behavior on color {
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
                        border.width: 0

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
    }
}
