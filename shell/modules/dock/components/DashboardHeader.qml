pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    signal requestHide()

    implicitWidth: parent ? parent.width : 1000
    implicitHeight: 52

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // Left: Branding / Greeting
        RowLayout {
            spacing: Tokens.spacing.small
            Layout.alignment: Qt.AlignVCenter

            StyledRect {
                implicitWidth: 36
                implicitHeight: 36
                radius: Tokens.rounding.medium
                color: Glass.enabled ? Glass.frost : Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "dashboard"
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                }
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Tr.tr("Workspace")
                    font: Tokens.font.title.small
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                }

                StyledText {
                    text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                    font: Tokens.font.label.small
                    color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 30
        }

        // Center: Brave Search Box
        StyledRect {
            id: searchBox

            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Tokens.rounding.full
            color: Glass.enabled ? (searchField.activeFocus ? Glass.frostHigh : Glass.mist) : (searchField.activeFocus ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh)
            border.width: searchField.activeFocus ? 1 : 0
            border.color: Glass.enabled ? Glass.rim : Colours.palette.m3primary

            Behavior on color {
                CAnim {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.small
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "search"
                    color: searchField.activeFocus ? (Glass.enabled ? Glass.ice : Colours.palette.m3primary) : (Glass.enabled ? Glass.haze : Colours.palette.m3outline)
                    fontStyle: Tokens.font.icon.medium
                }

                TextInput {
                    id: searchField

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Tokens.font.body.medium.family
                    font.pixelSize: 14
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                    selectedTextColor: Colours.palette.m3onPrimary
                    selectionColor: Colours.palette.m3primary
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: Tr.tr("Search web with Brave or type URL...")
                        color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                        font: searchField.font
                        visible: !searchField.text && !searchField.activeFocus
                        verticalAlignment: Text.AlignVCenter
                    }

                    onAccepted: {
                        const q = searchField.text.trim();
                        if (q.length > 0) {
                            if (q.startsWith("http://") || q.startsWith("https://") || (q.includes(".") && !q.includes(" "))) {
                                const url = (q.startsWith("http://") || q.startsWith("https://")) ? q : ("https://" + q);
                                Quickshell.execDetached(["distrobox-host-exec", "brave-browser", url]);
                            } else {
                                const searchUrl = "https://search.brave.com/search?q=" + encodeURIComponent(q);
                                Quickshell.execDetached(["distrobox-host-exec", "brave-browser", searchUrl]);
                            }
                            searchField.text = "";
                            searchField.focus = false;
                        }
                    }
                }

                // Brave logo pill
                StyledRect {
                    implicitWidth: braveLabel.implicitWidth + 14
                    implicitHeight: 26
                    radius: Tokens.rounding.full
                    color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHighest

                    Row {
                        id: braveLabel
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "travel_explore"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brave"
                            font: Tokens.font.label.small
                            color: Glass.enabled ? Glass.hazeHigh : Colours.palette.m3primary
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 30
        }

        // Right: Quick Action Controls & Clock
        RowLayout {
            spacing: Tokens.spacing.small
            Layout.alignment: Qt.AlignVCenter

            // DND button
            StyledRect {
                id: dndBtn

                implicitWidth: 36
                implicitHeight: 36
                radius: Tokens.rounding.full
                color: Notifs.dnd ? Colours.palette.m3errorContainer : (dndHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (Glass.enabled ? Glass.mist : Colours.palette.m3surfaceContainer))

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Notifs.dnd ? "notifications_off" : "notifications"
                    color: Notifs.dnd ? Colours.palette.m3onErrorContainer : (Glass.enabled ? Glass.ice : Colours.palette.m3onSurface)
                    fontStyle: Tokens.font.icon.small
                }

                HoverHandler {
                    id: dndHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.dnd = !Notifs.dnd
                }
            }

            // Lock screen button
            StyledRect {
                id: lockBtn

                implicitWidth: 36
                implicitHeight: 36
                radius: Tokens.rounding.full
                color: lockHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (Glass.enabled ? Glass.mist : Colours.palette.m3surfaceContainer)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "lock"
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.small
                }

                HoverHandler {
                    id: lockHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["jellyface", "lock"])
                }
            }

            // Live Time Pill
            StyledRect {
                implicitWidth: timeText.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: 36
                radius: Tokens.rounding.full
                color: Glass.enabled ? Glass.frost : Colours.palette.m3secondaryContainer

                StyledText {
                    id: timeText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font: Tokens.font.title.small
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSecondaryContainer

                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }
            }

            // Hide / Slide down button
            StyledRect {
                id: hideBtn

                implicitWidth: 36
                implicitHeight: 36
                radius: Tokens.rounding.full
                color: hideHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (Glass.enabled ? Glass.mist : Colours.palette.m3surfaceContainer)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_down"
                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.medium
                }

                HoverHandler {
                    id: hideHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestHide()
                }
            }
        }
    }
}
