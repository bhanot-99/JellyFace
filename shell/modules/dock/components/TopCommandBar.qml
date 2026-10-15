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

    cardId: "commandBar"
    title: Tr.tr("Command Bar")
    minW: 580
    minH: 52
    canResize: true
    contentPadding: 12

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // 1. Left: Branding & Distro
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

        // 2. Center: Brave Direct Search Box with Regex Domain Detection
        Rectangle {
            id: searchBox

            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: searchField.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : (searchHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04))
            border.width: 1
            border.color: searchField.activeFocus ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.08)

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
                        const trimmed = searchField.text.trim();
                        if (trimmed.length > 0) {
                            // Regex domain check: ^[\w-]+\.[a-z]{2,}(/.*)?$ or starts with http:// or https://
                            const isUrl = trimmed.startsWith("http://") || trimmed.startsWith("https://") || /^[\w-]+\.[a-z]{2,}(\/.*)?$/i.test(trimmed);
                            if (isUrl) {
                                const url = (trimmed.startsWith("http://") || trimmed.startsWith("https://")) ? trimmed : ("https://" + trimmed);
                                Quickshell.execDetached(["distrobox-host-exec", "brave-browser", url]);
                            } else {
                                const searchUrl = "https://search.brave.com/search?q=" + encodeURIComponent(trimmed);
                                Quickshell.execDetached(["distrobox-host-exec", "brave-browser", searchUrl]);
                            }
                            searchField.text = "";
                            searchField.focus = false;
                        }
                    }
                }

                // Instant Brave Browser Launch Button
                Rectangle {
                    id: braveLaunchBtn

                    implicitWidth: braveLabel.implicitWidth + 12
                    implicitHeight: 24
                    radius: 8
                    color: braveHover.hovered ? Qt.rgba(251 / 255, 146 / 255, 60 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: braveHover.hovered ? "#fb923c" : Qt.rgba(1, 1, 1, 0.06)

                    Row {
                        id: braveLabel
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "travel_explore"
                            color: "#fb923c"
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brave"
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.90)
                        }
                    }

                    HoverHandler {
                        id: braveHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", "brave-browser"])
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 20
        }

        // 3. Right: Command Actions & Dynamic Clock
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            // Notification Center Toggle Bell
            Rectangle {
                id: notifBell

                readonly property bool notifVis: DashboardState.isCardVisible("notifications", true)

                implicitWidth: 32
                implicitHeight: 32
                radius: 8
                color: notifBellHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : (notifVis ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.04))
                border.width: 1
                border.color: notifVis ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.06)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Notifs.dnd ? "notifications_off" : "notifications"
                    color: notifBell.notifVis ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.60)
                    fontStyle: Tokens.font.icon.small
                }

                HoverHandler {
                    id: notifBellHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DashboardState.setCardVisible("notifications", !notifBell.notifVis)
                }
            }

            // Global Edit / Lock Mode Toggle Pill Button
            Rectangle {
                id: lockToggleBtn

                implicitWidth: lockContent.implicitWidth + 18
                implicitHeight: 32
                radius: 8
                color: !DashboardState.isLocked ? Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.25) : (lockHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                border.width: 1
                border.color: !DashboardState.isLocked ? "#f59e0b" : Qt.rgba(255, 255, 255, 0.08)

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

                Row {
                    id: lockContent
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? "lock" : "lock_open"
                        color: !DashboardState.isLocked ? "#f59e0b" : Qt.rgba(1, 1, 1, 0.80)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? Tr.tr("Lock") : Tr.tr("Edit Mode")
                        font: Tokens.font.label.small
                        color: !DashboardState.isLocked ? "#f59e0b" : Qt.rgba(1, 1, 1, 0.85)
                    }
                }

                HoverHandler {
                    id: lockHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DashboardState.toggleLock()
                }
            }

            // Dynamic 1-Second Refresh Live Clock with Tabular Numerals
            Rectangle {
                implicitWidth: clockText.implicitWidth + 18
                implicitHeight: 32
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)

                StyledText {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), "hh:mm:ss")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Qt.rgba(1, 1, 1, 0.95)

                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm:ss")
                    }
                }
            }
        }
    }
}
