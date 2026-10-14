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

// Clipboard history popup (jellyface ipc clipboard toggle). Type to search, arrows + Enter or a click copies an
// entry (then press Ctrl+V where you want it), Esc closes.
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

            StyledRect {
                id: panel

                readonly property var shown: {
                    const q = search.text.trim().toLowerCase();
                    const all = Clipboard.entries.slice().sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
                    return q ? all.filter(e => e.kind === "text" && e.text.toLowerCase().includes(q)) : all;
                }

                anchors.centerIn: parent
                implicitWidth: 580
                implicitHeight: Math.min(parent.height - 120, 560)
                radius: Tokens.rounding.extraLarge
                color: Colours.palette.m3surface

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        SearchBar {
                            id: search

                            Layout.fillWidth: true
                            placeholderText: Tr.tr("Search clipboard history")
                            Component.onCompleted: forceActiveFocus()
                            Keys.onEscapePressed: Clipboard.open = false
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onReturnPressed: {
                                const e = panel.shown[list.currentIndex];
                                if (e) {
                                    Clipboard.copy(e);
                                    Clipboard.open = false;
                                }
                            }
                            onTextChanged: list.currentIndex = 0
                        }

                        IconButton {
                            icon: "delete_sweep"
                            type: IconButton.Text
                            onClicked: Clipboard.clear()
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.padding.extraLarge
                        visible: panel.shown.length === 0
                        text: Clipboard.entries.length === 0 ? Tr.tr("Nothing copied yet") : Tr.tr("No matches")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.medium
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.shown.length > 0
                        clip: true
                        spacing: Tokens.spacing.small
                        model: panel.shown
                        currentIndex: 0
                        highlightMoveDuration: 80

                        delegate: StyledRect {
                            id: item

                            required property var modelData
                            required property int index

                            width: ListView.view.width
                            implicitHeight: Math.max(52, row.implicitHeight + Tokens.padding.medium * 2)
                            radius: Tokens.rounding.large
                            color: ListView.isCurrentItem ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

                            StateLayer {
                                onClicked: {
                                    Clipboard.copy(item.modelData);
                                    Clipboard.open = false;
                                }
                            }

                            RowLayout {
                                id: row

                                anchors.fill: parent
                                anchors.margins: Tokens.padding.medium
                                spacing: Tokens.spacing.medium

                                MaterialIcon {
                                    text: item.modelData.kind === "image" ? "image" : "content_paste"
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                Image {
                                    visible: item.modelData.kind === "image"
                                    source: visible ? `file://${item.modelData.file}` : ""
                                    sourceSize.height: 96
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    Layout.preferredHeight: 48
                                    Layout.preferredWidth: 96
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: item.modelData.kind === "text"
                                    text: item.modelData.text.trim()
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    font: Tokens.font.body.small
                                }

                                Item {
                                    visible: item.modelData.kind === "image"
                                    Layout.fillWidth: true
                                }

                                IconButton {
                                    icon: "push_pin"
                                    type: item.modelData.pinned ? IconButton.Filled : IconButton.Text
                                    onClicked: Clipboard.togglePin(item.modelData)
                                }

                                IconButton {
                                    icon: "close"
                                    type: IconButton.Text
                                    onClicked: Clipboard.remove(item.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
