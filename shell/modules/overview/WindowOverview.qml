pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.utils

// Mission Control / Exposé Window Overview: Displays all active windows on the current workspace
// in an interactive frosted-glass grid. Super+W toggles it.
Scope {
    id: root

    readonly property var activeWindows: CosmicWindows.windows.filter(w => w.workspace_active && !w.minimized)

    StyledWindow {
        id: win

        readonly property var winList: root.activeWindows
        property int selectedIndex: 0

        function focusWindow(w: var): void {
            if (!w)
                return;
            CosmicWindows.activate(w.id);
            Overview.open = false;
        }

        screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
        name: "window-overview"
        visible: Overview.open
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        BackgroundEffect.blurRegion: wholeScreen

        Region {
            id: wholeScreen

            width: win.width
            height: win.height
        }

        // Frosted glass background veil
        Rectangle {
            id: veil

            anchors.fill: parent
            color: Colours.light ? Qt.rgba(0.92, 0.93, 0.95, 0.70) : Qt.rgba(0.14, 0.15, 0.17, 0.64)
        }

        // Dismiss on empty background click
        MouseArea {
            anchors.fill: parent
            onClicked: Overview.open = false
        }

        Item {
            id: container

            anchors.fill: parent
            anchors.margins: 40

            // Header Bar
            RowLayout {
                id: header

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "dashboard"
                    color: Colours.palette.m3primary
                    font.pointSize: 20
                }

                StyledText {
                    text: Tr.tr("Mission Control")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.headline.small
                }

                StyledText {
                    text: `(${win.winList.length} ${Tr.tr("windows")})`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                    Layout.alignment: Qt.AlignBaseline
                }
            }

            // Keyboard navigation
            Item {
                focus: win.visible
                Keys.onEscapePressed: Overview.open = false
                Keys.onReturnPressed: win.focusWindow(win.winList[win.selectedIndex])
                Keys.onEnterPressed: win.focusWindow(win.winList[win.selectedIndex])
                Keys.onLeftPressed: win.selectedIndex = Math.max(0, win.selectedIndex - 1)
                Keys.onRightPressed: win.selectedIndex = Math.min(win.winList.length - 1, win.selectedIndex + 1)
                Keys.onUpPressed: win.selectedIndex = Math.max(0, win.selectedIndex - 3)
                Keys.onDownPressed: win.selectedIndex = Math.min(win.winList.length - 1, win.selectedIndex + 3)
            }

            // Empty state
            StyledText {
                anchors.centerIn: parent
                visible: win.winList.length === 0
                text: Tr.tr("No active windows on this workspace")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.large
            }

            // Cards Grid
            Flow {
                anchors.top: header.bottom
                anchors.topMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(container.width, Math.max(1, Math.min(win.winList.length, 4)) * 300)
                spacing: 24

                Repeater {
                    model: win.winList

                    StyledRect {
                        id: card

                        required property var modelData
                        required property int index

                        readonly property bool isSelected: win.selectedIndex === index

                        width: 280
                        height: 180
                        radius: Tokens.rounding.large
                        color: area.containsMouse || isSelected ? Glass.glassPillHover : Glass.sheet

                        GlassBevel {
                            radius: card.radius
                        }

                        // Top header inside card
                        RowLayout {
                            id: cardHeader

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 12
                            spacing: 8

                            IconImage {
                                implicitSize: 22
                                source: Quickshell.iconPath(card.modelData.app_id || "", "application-x-executable")
                                asynchronous: true
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: card.modelData.app_id || Tr.tr("Window")
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.label.large
                            }

                            // Close window button
                            MaterialIcon {
                                text: "close"
                                color: closeArea.containsMouse ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                                font.pointSize: 14

                                MouseArea {
                                    id: closeArea

                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: CosmicWindows.close(card.modelData.id)
                                }
                            }
                        }

                        // Window Title & Preview Box
                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 12
                            width: parent.width - 32
                            spacing: 8

                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: 48
                                source: Quickshell.iconPath(card.modelData.app_id || "", "application-x-executable")
                                asynchronous: true
                            }

                            StyledText {
                                width: parent.width
                                text: card.modelData.title || card.modelData.app_id || ""
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.body.medium
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.focusWindow(card.modelData)
                        }
                    }
                }
            }
        }
    }
}
