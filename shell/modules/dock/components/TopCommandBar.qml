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
    contentPadding: 10

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // 1. Left: Branding & Distro in Elevated Tactile Squircle
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 12
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
                border.color: Qt.rgba(1, 1, 1, 0.14)

                // Top-lit bevel specular hairline
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.28)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "dashboard"
                    color: "#FFFFFF"
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Tr.tr("Workspace")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: "#FFFFFF"
                }

                StyledText {
                    text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                    font: Tokens.font.label.small
                    color: "#9CA3AF"
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 16
        }

        // 2. Center: Brave Direct Search Box as Recessed Inset Pill Well
        Rectangle {
            id: searchBox

            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 9999
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "#1b1c20"
                }
                GradientStop {
                    position: 1.0
                    color: "#24262b"
                }
            }
            border.width: 1
            border.color: searchField.activeFocus ? Qt.rgba(255, 255, 255, 0.35) : (searchHover.hovered ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.08))

            Behavior on border.color {
                CAnim {
                    duration: 150
                }
            }

            // Top recessed inner shadow hairline
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 1
                color: Qt.rgba(0, 0, 0, 0.65)
            }

            // Bottom subtle bevel reflection
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 1
                color: Qt.rgba(255, 255, 255, 0.06)
            }

            HoverHandler {
                id: searchHover
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 8

                MaterialIcon {
                    text: "search"
                    color: searchField.activeFocus ? "#FFFFFF" : "#9CA3AF"
                    fontStyle: Tokens.font.icon.small
                }

                TextInput {
                    id: searchField

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Tokens.font.body.medium.family
                    font.pixelSize: 13
                    color: "#FFFFFF"
                    selectedTextColor: "#FFFFFF"
                    selectionColor: "#444852"
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: Tr.tr("Search with Brave or enter URL...")
                        color: "#71717A"
                        font: searchField.font
                        visible: !searchField.text && !searchField.activeFocus
                        verticalAlignment: Text.AlignVCenter
                    }

                    onAccepted: {
                        const trimmed = searchField.text.trim();
                        if (trimmed.length > 0) {
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

                // Elevated Tactile Brave Button
                Rectangle {
                    id: braveLaunchBtn

                    implicitWidth: braveLabel.implicitWidth + 16
                    implicitHeight: 26
                    radius: 9999
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: braveHover.hovered ? "#4f5460" : "#444852"
                        }
                        GradientStop {
                            position: 1.0
                            color: braveHover.hovered ? "#383b44" : "#31343b"
                        }
                    }
                    border.width: 1
                    border.color: braveHover.hovered ? Qt.rgba(255, 255, 255, 0.30) : Qt.rgba(255, 255, 255, 0.15)

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.28)
                    }

                    Row {
                        id: braveLabel
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "travel_explore"
                            color: "#FFFFFF"
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brave"
                            font: Tokens.font.label.small
                            color: "#FFFFFF"
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
            Layout.maximumWidth: 16
        }

        // 3. Right: Tactile Command Action Buttons & Clock
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            // Notification Center Toggle Bell (Tactile Squircle)
            Rectangle {
                id: notifBell

                readonly property bool notifVis: DashboardState.isCardVisible("notifications", true)

                implicitWidth: 34
                implicitHeight: 34
                radius: 12
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: notifBellHover.hovered ? "#4f5460" : "#444852"
                    }
                    GradientStop {
                        position: 1.0
                        color: notifBellHover.hovered ? "#383b44" : "#31343b"
                    }
                }
                border.width: 1
                border.color: notifVis ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(255, 255, 255, 0.12)

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
                    text: Notifs.dnd ? "notifications_off" : "notifications"
                    color: "#FFFFFF"
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

                implicitWidth: lockContent.implicitWidth + 20
                implicitHeight: 34
                radius: 9999
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: !DashboardState.isLocked ? "#4f5460" : (lockHover.hovered ? "#444852" : "#373a42")
                    }
                    GradientStop {
                        position: 1.0
                        color: !DashboardState.isLocked ? "#383b44" : (lockHover.hovered ? "#31343b" : "#26282e")
                    }
                }
                border.width: 1
                border.color: !DashboardState.isLocked ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(255, 255, 255, 0.14)

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.28)
                }

                Row {
                    id: lockContent
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? "lock" : "lock_open"
                        color: "#FFFFFF"
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? Tr.tr("Lock") : Tr.tr("Edit Mode")
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: "#FFFFFF"
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
                implicitWidth: clockText.implicitWidth + 20
                implicitHeight: 34
                radius: 9999
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#373a42"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#26282e"
                    }
                }
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.12)

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.22)
                }

                StyledText {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), "hh:mm:ss")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: "#FFFFFF"

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
