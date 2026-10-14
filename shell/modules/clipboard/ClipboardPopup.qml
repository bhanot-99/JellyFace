pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// Clipboard history popup (Super+V / jellyface ipc clipboard toggle), laid out like the dashboard: a bento of tiles
// with differently shaped corners. Type to search, arrows or Tab to move, Enter or a click copies (then press Ctrl+V),
// Esc closes. Pinned entries are tinted and come first.
Scope {
    LazyLoader {
        active: Clipboard.open

        StyledWindow {
            id: win

            screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
            name: "clipboard"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                onClicked: Clipboard.open = false
            }

            Item {
                id: panel

                readonly property var shown: {
                    const q = search.text.trim().toLowerCase();
                    const all = Clipboard.entries.slice().sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
                    return q ? all.filter(e => e.kind === "text" && e.text.toLowerCase().includes(q)) : all;
                }
                readonly property real gap: Tokens.spacing.medium

                anchors.centerIn: parent
                width: 640
                height: Math.min(parent.height - 120, 600)

                // Swallow clicks so they don't close the popup
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: panel.gap

                    // Header tiles: search pill, entry counter, clear button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: panel.gap

                        SearchBar {
                            id: search

                            Layout.fillWidth: true
                            placeholderText: Tr.tr("Search clipboard history")
                            Component.onCompleted: forceActiveFocus()
                            Keys.onEscapePressed: Clipboard.open = false
                            Keys.onDownPressed: grid.moveCurrentIndexDown()
                            Keys.onUpPressed: grid.moveCurrentIndexUp()
                            Keys.onTabPressed: grid.moveCurrentIndexRight()
                            Keys.onBacktabPressed: grid.moveCurrentIndexLeft()
                            Keys.onReturnPressed: {
                                const e = panel.shown[grid.currentIndex];
                                if (e) {
                                    Clipboard.copy(e);
                                    Clipboard.open = false;
                                }
                            }
                            onTextChanged: grid.currentIndex = 0
                        }

                        StyledRect {
                            implicitWidth: 56
                            implicitHeight: 56
                            color: Colours.palette.m3tertiaryContainer
                            topLeftRadius: Tokens.rounding.large
                            topRightRadius: 28
                            bottomLeftRadius: 28
                            bottomRightRadius: Tokens.rounding.large

                            StyledText {
                                anchors.centerIn: parent
                                text: panel.shown.length
                                color: Colours.palette.m3onTertiaryContainer
                                font: Tokens.font.body.large
                            }
                        }

                        StyledRect {
                            implicitWidth: 56
                            implicitHeight: 56
                            color: Colours.palette.m3errorContainer
                            radius: 28
                            topRightRadius: Tokens.rounding.small

                            StateLayer {
                                color: Colours.palette.m3onErrorContainer
                                onClicked: Clipboard.clear()
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "delete_sweep"
                                color: Colours.palette.m3onErrorContainer
                            }
                        }
                    }

                    // Empty state
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.shown.length === 0
                        color: Colours.palette.m3surface
                        radius: Tokens.rounding.extraLarge * 1.5

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: "content_paste_off"
                                color: Colours.palette.m3outline
                                fontStyle: Tokens.font.icon.extraLarge
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Clipboard.entries.length === 0 ? Tr.tr("Nothing copied yet") : Tr.tr("No matches")
                                color: Colours.palette.m3outline
                                font: Tokens.font.body.medium
                            }
                        }
                    }

                    // Entry tiles: two columns, corner shapes cycle through three variants
                    GridView {
                        id: grid

                        readonly property real cellGap: panel.gap

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.shown.length > 0
                        clip: true
                        cellWidth: Math.floor(width / 2)
                        cellHeight: 112
                        model: panel.shown
                        currentIndex: 0
                        keyNavigationEnabled: false
                        highlightMoveDuration: 0

                        delegate: Item {
                            id: cell

                            required property var modelData
                            required property int index
                            readonly property bool current: GridView.isCurrentItem
                            readonly property bool image: modelData.kind === "image"
                            readonly property bool pinned: !!modelData.pinned
                            readonly property real big: 40
                            readonly property real small: Tokens.rounding.small

                            width: grid.cellWidth
                            height: grid.cellHeight

                            StyledClippingRect {
                                id: tile

                                anchors.fill: parent
                                anchors.rightMargin: index % 2 === 0 ? grid.cellGap / 2 : 0
                                anchors.leftMargin: index % 2 === 1 ? grid.cellGap / 2 : 0
                                anchors.bottomMargin: grid.cellGap

                                color: cell.pinned ? Colours.palette.m3primaryContainer : cell.current ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh
                                // Leaf / pill / mirrored leaf
                                topLeftRadius: [cell.big, 20, cell.small][cell.index % 3]
                                topRightRadius: [cell.small, 20, cell.big][cell.index % 3]
                                bottomLeftRadius: [cell.small, 20, cell.big][cell.index % 3]
                                bottomRightRadius: [cell.big, 20, cell.small][cell.index % 3]
                                border.width: cell.current ? 2 : 0
                                border.color: Colours.palette.m3primary

                                Image {
                                    anchors.fill: parent
                                    visible: cell.image
                                    source: cell.image ? `file://${cell.modelData.file}` : ""
                                    sourceSize.width: 400
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                StateLayer {
                                    color: cell.pinned ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    onClicked: {
                                        Clipboard.copy(cell.modelData);
                                        Clipboard.open = false;
                                    }
                                    onEntered: grid.currentIndex = cell.index
                                }

                                StyledText {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.large
                                    anchors.rightMargin: Tokens.padding.large + 8
                                    visible: !cell.image
                                    text: cell.modelData.text.trim()
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    color: cell.pinned ? Colours.palette.m3onPrimaryContainer : cell.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    font: Tokens.font.body.small
                                }

                                // Hover actions: pin and delete as little round buttons
                                Row {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: Tokens.padding.small
                                    spacing: Tokens.spacing.small
                                    opacity: cell.current || cell.pinned ? 1 : 0

                                    Repeater {
                                        model: [
                                            {
                                                icon: "push_pin",
                                                act: "pin"
                                            },
                                            {
                                                icon: "close",
                                                act: "del"
                                            }
                                        ]

                                        StyledRect {
                                            id: btn

                                            required property var modelData

                                            // A pinned entry only shows its pin; the delete button needs hover or focus
                                            visible: modelData.act === "pin" || cell.current
                                            width: 28
                                            height: 28
                                            radius: Tokens.rounding.full
                                            color: modelData.act === "pin" && cell.pinned ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3surface, 0.75)

                                            StateLayer {
                                                onClicked: btn.modelData.act === "pin" ? Clipboard.togglePin(cell.modelData) : Clipboard.remove(cell.modelData)
                                            }

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: btn.modelData.icon
                                                color: btn.modelData.act === "pin" && cell.pinned ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                                fill: btn.modelData.act === "pin" && cell.pinned ? 1 : 0
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
        }
    }
}
