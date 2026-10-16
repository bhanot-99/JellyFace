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

        // 1. Left: Branding & Distro in Elevated Tactile Squircle (Glass.glassElevatedTile + Glass.glassRimTop)
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: Tokens.rounding.medium
                color: Glass.glassElevatedTile
                border.width: 1
                border.color: Glass.glassBorder

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "dashboard"
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Tr.tr("Workspace")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Glass.textPrimary
                }

                StyledText {
                    text: SysInfo.osPrettyName || "Pop!_OS 24.04"
                    font: Tokens.font.label.small
                    color: Glass.textSecondary
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: 16
        }

        // 2. Center: Brave Direct Search Box as Recessed Inset Pill Well (Glass.glassRecessedWell + Glass.glassBorder)
        Rectangle {
            id: searchBox

            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Tokens.rounding.full
            color: searchField.activeFocus ? (Glass.enabled ? Qt.rgba(0.05, 0.07, 0.10, 0.88) : Colours.palette.m3surfaceDim) : Glass.glassRecessedWell
            border.width: 1
            border.color: searchField.activeFocus ? Glass.glassActivePill : (searchBoxMouse.containsMouse ? Glass.glassBorderHover : Glass.glassBorder)

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
                    color: searchIconMouse.containsMouse ? Glass.glassPillHover : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "search"
                        color: searchField.activeFocus ? Glass.glassActivePill : Glass.textSecondary
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
                        color: Glass.textPrimary
                        selectedTextColor: Glass.textDark
                        selectionColor: Glass.glassActivePill
                        selectByMouse: true
                        activeFocusOnPress: true
                        cursorVisible: activeFocus
                        clip: true

                        Text {
                            anchors.fill: parent
                            text: Tr.tr("Search with Brave or enter URL...")
                            color: Glass.textMuted
                            opacity: 0.90
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
                    color: clearMouse.containsMouse ? Glass.glassPillHover : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        color: Glass.textSecondary
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
                    color: braveMouse.pressed ? Glass.glassActivePill : (braveMouse.containsMouse ? Glass.glassPillHover : Glass.glassElevatedTile)
                    border.width: 1
                    border.color: braveMouse.containsMouse ? Glass.glassActivePill : Glass.glassBorder
                    scale: braveMouse.pressed ? 0.94 : (braveMouse.containsMouse ? 1.03 : 1.0)

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    Row {
                        id: braveLabel
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "travel_explore"
                            color: braveMouse.pressed ? Glass.textDark : Glass.textPrimary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brave"
                            font: Tokens.font.label.small
                            color: braveMouse.pressed ? Glass.textDark : Glass.textPrimary
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

            // Notification Center Toggle Bell (Glass.glassElevatedTile Squircle)
            Rectangle {
                id: notifBell

                readonly property bool notifVis: DashboardState.isCardVisible("notifications", true)

                implicitWidth: 34
                implicitHeight: 34
                radius: Tokens.rounding.medium
                color: notifBellMouse.pressed ? Glass.glassActivePill : (notifBellMouse.containsMouse ? Glass.glassPillHover : Glass.glassElevatedTile)
                border.width: 1
                border.color: notifVis || notifBellMouse.containsMouse ? Glass.glassActivePill : Glass.glassBorder
                scale: notifBellMouse.pressed ? 0.94 : (notifBellMouse.containsMouse ? 1.05 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Notifs.dnd ? "notifications_off" : "notifications"
                    color: notifBellMouse.pressed ? Glass.textDark : Glass.textPrimary
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
                color: !DashboardState.isLocked ? Glass.glassActivePill : (lockMouse.pressed ? Glass.glassPillHover : (lockMouse.containsMouse ? Glass.glassPillHover : Glass.glassElevatedTile))
                border.width: 1
                border.color: !DashboardState.isLocked || lockMouse.containsMouse ? Glass.glassActivePill : Glass.glassBorder
                scale: lockMouse.pressed ? 0.94 : (lockMouse.containsMouse ? 1.04 : 1.0)

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Row {
                    id: lockContent
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? "lock" : "lock_open"
                        color: !DashboardState.isLocked ? Glass.textDark : Glass.textPrimary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DashboardState.isLocked ? Tr.tr("Lock") : Tr.tr("Edit Mode")
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: !DashboardState.isLocked ? Glass.textDark : Glass.textPrimary
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
                color: Glass.glassElevatedTile
                border.width: 1
                border.color: Glass.glassBorder

                StyledText {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(Time.date, "hh:mm:ss")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Glass.textPrimary
                }
            }
        }
    }
}
