pragma ComponentBehavior: Bound

import "../lock"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.services

// JellyFace's own overview (3-finger swipe up opens COSMIC's instead, see CosmicOverview.qml): the windows open on the workspace you are looking at, as a grid of cards
// (jellyface ipc overview toggle). Click a card or press Enter to focus that window; the x on a card closes it.
// Esc, a click on the background or a 3-finger swipe down closes it.
// COSMIC offers no window thumbnails to other programs, so a card shows the app's icon, name and window title.
Scope {
    id: root

    required property Lock lock
    property bool open

    readonly property var windows: CosmicWindows.windows.filter(w => w.workspace_active)

    function focus(w: var): void {
        CosmicWindows.activate(w.id);
        open = false;
    }

    Connections {
        target: Gestures

        function onSwiped(fingers: int, direction: string): void {
            if (fingers !== 3 || root.lock.lock.locked)
                return;
            // (swipe up = COSMIC's own overview: CosmicOverview.qml)
            if (direction === "down")
                root.open = false;
        }
    }

    Connections {
        target: root.lock.lock

        function onLockedChanged(): void {
            if (root.lock.lock.locked)
                root.open = false;
        }
    }

    IpcHandler {
        function toggle(): void {
            root.open = !root.open && !root.lock.lock.locked;
        }

        function open(): void {
            root.open = !root.lock.lock.locked;
        }

        function close(): void {
            root.open = false;
        }

        target: "overview"
    }

    LazyLoader {
        active: root.open

        StyledWindow {
            id: win

            screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
            name: "overview"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Rectangle {
                id: scrim

                anchors.fill: parent
                color: Colours.palette.m3scrim
                opacity: 0
                Component.onCompleted: opacity = 0.5

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.anim.durations.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            ColumnLayout {
                id: content

                readonly property int columns: Math.max(1, Math.min(4, root.windows.length))

                anchors.centerIn: parent
                width: Math.min(parent.width - 160, columns * grid.cellWidth)
                spacing: Tokens.spacing.large
                opacity: 0
                scale: 0.94
                Component.onCompleted: {
                    opacity = 1;
                    scale = 1;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.anim.durations.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.anim.durations.normal
                        easing.type: Easing.OutCubic
                    }
                }

                // Header: workspace name and window count
                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: header.implicitWidth + Tokens.padding.extraLarge * 2
                    implicitHeight: header.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHigh

                    RowLayout {
                        id: header

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "select_window"
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            readonly property var ws: CosmicWs.list[CosmicWs.activeIndex]

                            text: (ws?.name ? Tr.tr("Workspace %1").arg(ws.name) : Tr.tr("This workspace")) + "  ·  " + (root.windows.length === 1 ? Tr.tr("1 window") : Tr.tr("%1 windows").arg(root.windows.length))
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                        }
                    }
                }

                // Empty state
                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.windows.length === 0
                    implicitWidth: 360
                    implicitHeight: 180
                    radius: Tokens.rounding.extraLarge
                    color: Colours.palette.m3surface

                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "web_asset_off"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.extraLarge
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Tr.tr("No windows on this workspace")
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.medium
                        }
                    }
                }

                GridView {
                    id: grid

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(win.height - 240, Math.ceil(count / content.columns) * cellHeight)
                    visible: count > 0
                    clip: true
                    interactive: contentHeight > height
                    cellWidth: 280
                    cellHeight: 200
                    model: root.windows
                    currentIndex: Math.max(0, root.windows.findIndex(w => w.activated))
                    keyNavigationEnabled: true
                    focus: true
                    highlightMoveDuration: 0

                    Keys.onEscapePressed: root.open = false
                    Keys.onReturnPressed: root.focus(root.windows[currentIndex])
                    Keys.onEnterPressed: root.focus(root.windows[currentIndex])
                    Keys.onDeletePressed: CosmicWindows.close(root.windows[currentIndex].id)

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index
                        readonly property bool current: GridView.isCurrentItem
                        readonly property var entry: DesktopEntries.heuristicLookup(modelData.app_id)

                        width: grid.cellWidth
                        height: grid.cellHeight

                        StyledRect {
                            id: card

                            anchors.fill: parent
                            anchors.margins: Tokens.spacing.small
                            radius: Tokens.rounding.extraLarge
                            color: cell.current ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainer
                            border.width: cell.modelData.activated ? 2 : 0
                            border.color: Colours.palette.m3primary
                            opacity: cell.modelData.minimized ? 0.7 : 1

                            StateLayer {
                                color: Colours.palette.m3onSurface
                                onClicked: root.focus(cell.modelData)
                                onEntered: grid.currentIndex = cell.index
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.large
                                spacing: Tokens.spacing.small

                                IconImage {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Tokens.padding.small
                                    implicitSize: 64
                                    source: Quickshell.iconPath(cell.entry?.icon ?? cell.modelData.app_id, "application-x-executable")
                                    asynchronous: true
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: cell.entry?.name ?? cell.modelData.app_id ?? ""
                                    elide: Text.ElideRight
                                    color: cell.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    font: Tokens.font.body.large
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignTop
                                    text: (cell.modelData.minimized ? Tr.tr("Minimized") + " · " : "") + cell.modelData.title
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.body.small
                                }
                            }

                            // Close button, shown on the card under the cursor or keyboard selection
                            StyledRect {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Tokens.padding.small
                                implicitWidth: 32
                                implicitHeight: 32
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3errorContainer
                                opacity: cell.current ? 1 : 0

                                StateLayer {
                                    color: Colours.palette.m3onErrorContainer
                                    onClicked: CosmicWindows.close(cell.modelData.id)
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "close"
                                    color: Colours.palette.m3onErrorContainer
                                    fontStyle: Tokens.font.icon.small
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
