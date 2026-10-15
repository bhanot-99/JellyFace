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

    implicitWidth: parent ? parent.width : 1000
    implicitHeight: 44

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Left: Branding Badge
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "dashboard"
                    color: Qt.rgba(1, 1, 1, 0.95)
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Tr.tr("Workspace")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Qt.rgba(1, 1, 1, 0.95)
                }

                StyledText {
                    text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                    font: Tokens.font.label.small
                    color: Qt.rgba(1, 1, 1, 0.50)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 20
        }

        // Center: Brave Search Box
        Rectangle {
            id: searchBox

            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: searchField.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : (searchHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04))
            border.width: 1
            border.color: searchField.activeFocus ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.08)

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

            HoverHandler {
                id: searchHover
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 8

                MaterialIcon {
                    text: "search"
                    color: searchField.activeFocus ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.45)
                    fontStyle: Tokens.font.icon.small
                }

                TextInput {
                    id: searchField

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Tokens.font.body.medium.family
                    font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.95)
                    selectedTextColor: "#ffffff"
                    selectionColor: Colours.palette.m3primary
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: Tr.tr("Search with Brave or enter URL...")
                        color: Qt.rgba(1, 1, 1, 0.40)
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
                Rectangle {
                    implicitWidth: braveLabel.implicitWidth + 12
                    implicitHeight: 24
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    Row {
                        id: braveLabel
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "travel_explore"
                            color: "#fb923c" // Brave orange accent
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brave"
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 20
        }

        // Right: Action Controls & Tabular Clock
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            // DND button
            Rectangle {
                id: dndBtn

                implicitWidth: 32
                implicitHeight: 32
                radius: 8
                color: Notifs.dnd ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.20) : (dndHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                border.width: 1
                border.color: Notifs.dnd ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.40) : Qt.rgba(1, 1, 1, 0.06)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Notifs.dnd ? "notifications_off" : "notifications"
                    color: Notifs.dnd ? "#f87171" : Qt.rgba(1, 1, 1, 0.80)
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
            Rectangle {
                id: lockBtn

                implicitWidth: 32
                implicitHeight: 32
                radius: 8
                color: lockHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "lock"
                    color: Qt.rgba(1, 1, 1, 0.80)
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

            // Live Time Pill with Tabular Figures
            Rectangle {
                implicitWidth: timeText.implicitWidth + 18
                implicitHeight: 32
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                StyledText {
                    id: timeText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Qt.rgba(1, 1, 1, 0.95)

                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }
            }
        }
    }
}
