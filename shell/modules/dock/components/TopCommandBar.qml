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

    readonly property bool searchFocused: searchField.activeFocus
    function unfocusSearch(): void {
        searchField.text = "";
        searchField.focus = false;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // 1. Left: Branding & Distro in Elevated Tactile Squircle (Glass.frost + Glass.rim)
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: Tokens.rounding.medium
                color: Glass.frost
                border.width: 1
                border.color: Glass.rim

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

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "dashboard"
                    color: Glass.ice
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Tr.tr("Workspace")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Glass.ice
                }

                StyledText {
                    text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                    font: Tokens.font.label.small
                    color: Glass.haze
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 16
        }

        // 2. Center: Brave Direct Search Box as Recessed Inset Pill Well (Glass.well + Glass.rim)
        Rectangle {
            id: searchBox

            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Tokens.rounding.full
            color: searchField.activeFocus ? Qt.rgba(0.08, 0.10, 0.14, 0.85) : Glass.well
            border.width: 1
            border.color: searchField.activeFocus ? Glass.ice : (searchBoxMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Glass.rim)

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

            // Click anywhere on the search pill well to immediately focus and type
            MouseArea {
                id: searchBoxMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                z: 0
                onClicked: searchField.forceActiveFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 8
                z: 1

                // Search icon button (submits search if text exists, otherwise focuses)
                Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: Tokens.rounding.full
                    color: searchIconMouse.containsMouse ? Glass.frost : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "search"
                        color: searchField.activeFocus ? Glass.ice : Glass.haze
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        id: searchIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (searchField.text.trim().length > 0) {
                                searchField.accepted();
                            } else {
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                }

                // Dedicated text input container spanning full width and height
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextInput {
                        id: searchField

                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Tokens.font.body.medium.family
                        font.pixelSize: 13
                        color: Glass.ice
                        selectedTextColor: Glass.ink
                        selectionColor: Glass.ice
                        selectByMouse: true
                        activeFocusOnPress: true
                        cursorVisible: activeFocus
                        clip: true

                        Text {
                            anchors.fill: parent
                            text: Tr.tr("Search with Brave or enter URL...")
                            color: Glass.haze
                            opacity: 0.60
                            font: searchField.font
                            visible: !searchField.text && !searchField.activeFocus
                            verticalAlignment: Text.AlignVCenter
                            enabled: false
                        }

                        Keys.onReturnPressed: searchField.accepted()
                        Keys.onEnterPressed: searchField.accepted()
                        Keys.onEscapePressed: {
                            searchField.text = "";
                            searchField.focus = false;
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
                }

                // Clear button when text is present
                Rectangle {
                    visible: searchField.text.length > 0
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: Tokens.rounding.full
                    color: clearMouse.containsMouse ? Glass.frostHigh : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        color: Glass.haze
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchField.text = "";
                            searchField.forceActiveFocus();
                        }
                    }
                }

                // Elevated Tactile Brave Button (Glass.frost + scale: 0.96 on press)
                Rectangle {
                    id: braveLaunchBtn
                    z: 5

                    implicitWidth: braveLabel.implicitWidth + 16
                    implicitHeight: 26
                    radius: Tokens.rounding.full
                    color: braveMouse.pressed ? Glass.frostHigh : (braveMouse.containsMouse ? Glass.frostHigh : Glass.frost)
                    border.width: 1
                    border.color: braveMouse.containsMouse ? Glass.ice : Glass.rim
                    scale: braveMouse.pressed ? 0.94 : (braveMouse.containsMouse ? 1.03 : 1.0)

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 1
                        color: Glass.ice
                        opacity: 0.35
                    }

                    Row {
                        id: braveLabel
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "travel_explore"
                            color: Glass.ice
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brave"
                            font: Tokens.font.label.small
                            color: Glass.ice
                        }
                    }

                    MouseArea {
                        id: braveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (searchField.text.trim().length > 0) {
                                searchField.accepted();
                            } else {
                                Quickshell.execDetached(["distrobox-host-exec", "brave-browser"]);
                            }
                        }
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

            // Notification Center Toggle Bell (Glass.frost Squircle)
            Rectangle {
                id: notifBell

                readonly property bool notifVis: DashboardState.isCardVisible("notifications", true)

                implicitWidth: 34
                implicitHeight: 34
                radius: Tokens.rounding.medium
                color: notifBellMouse.pressed ? Glass.frostHigh : (notifBellMouse.containsMouse ? Glass.frostHigh : Glass.frost)
                border.width: 1
                border.color: notifVis || notifBellMouse.containsMouse ? Glass.ice : Glass.rim
                scale: notifBellMouse.pressed ? 0.94 : (notifBellMouse.containsMouse ? 1.05 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

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
                    text: Notifs.dnd ? "notifications_off" : "notifications"
                    color: Glass.ice
                    fontStyle: Tokens.font.icon.small
                }

                MouseArea {
                    id: notifBellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DashboardState.setCardVisible("notifications", !notifBell.notifVis)
                }
            }

            // Global Edit / Lock Mode Toggle Pill Button
            Rectangle {
                id: lockToggleBtn

                implicitWidth: lockContent.implicitWidth + 20
                implicitHeight: 34
                radius: Tokens.rounding.full
                color: !DashboardState.isLocked ? Glass.ice : (lockMouse.pressed ? Glass.frostHigh : (lockMouse.containsMouse ? Glass.frostHigh : Glass.frost))
                border.width: 1
                border.color: !DashboardState.isLocked || lockMouse.containsMouse ? Glass.ice : Glass.rim
                scale: lockMouse.pressed ? 0.94 : (lockMouse.containsMouse ? 1.04 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: !DashboardState.isLocked ? "transparent" : Glass.ice
                    opacity: 0.35
                }

                Row {
                    id: lockContent
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? "lock" : "lock_open"
                        color: !DashboardState.isLocked ? Glass.ink : Glass.ice
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? Tr.tr("Lock") : Tr.tr("Edit Mode")
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: !DashboardState.isLocked ? Glass.ink : Glass.ice
                    }
                }

                MouseArea {
                    id: lockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DashboardState.toggleLock()
                }
            }

            // Dynamic 1-Second Refresh Live Clock with Tabular Numerals
            Rectangle {
                implicitWidth: clockText.implicitWidth + 20
                implicitHeight: 34
                radius: Tokens.rounding.full
                color: Glass.frost
                border.width: 1
                border.color: Glass.rim

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

                StyledText {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(Time.date, "hh:mm:ss")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Glass.ice
                }
            }
        }
    }
}
