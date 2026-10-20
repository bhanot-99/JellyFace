pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.quill
import qs.quill.components

// Desks (Super+W or Super+D; Super+W replaces COSMIC's own overview while Quill is on): every COSMIC workspace as a card with its windows drawn where they are (COSMIC lets no shell
// capture windows, so they are outlines with the app's icon and title, not pictures). Click a desk or a window, or
// ←/→ and Enter, or press its number.
Surface {
    id: root

    name: "desks"
    anchors.fill: parent

    property int current: CosmicWs.activeIndex
    readonly property real cardWidth: Math.min(330, (width - 160) / Math.max(1, CosmicWs.list.length) - 20)
    readonly property real ratio: (Quickshell.screens[0]?.height ?? 900) / (Quickshell.screens[0]?.width ?? 1440)

    function pick(i: int): void {
        QuillState.close();
        CosmicWs.activate(i);
    }

    onActiveChanged: if (active) current = Math.max(0, CosmicWs.activeIndex)

    Keys.onLeftPressed: current = Math.max(0, current - 1)
    Keys.onRightPressed: current = Math.min(CosmicWs.list.length - 1, current + 1)
    Keys.onReturnPressed: pick(current)
    Keys.onEnterPressed: pick(current)
    Keys.onPressed: e => {
        const n = parseInt(e.text);
        if (n >= 1 && n <= CosmicWs.list.length) {
            pick(n - 1);
            e.accepted = true;
        }
    }

    blur: Region {
        BlurRegion {
            pane: backdrop.body
        }
    }

    Glass {
        id: backdrop

        anchors.centerIn: parent
        width: row.width + 64
        height: row.height + 110
        color: Theme.sheet
        scale: 0.96 + 0.04 * root.progress

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 22
            spacing: 2

            Kicker {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Desks"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "As much space as you need."
                size: Theme.heading
                font.weight: Font.Medium
            }
        }

        Row {
            id: row

            anchors.horizontalCenter: parent.horizontalCenter
            y: 80
            spacing: 20

            Repeater {
                model: CosmicWs.list

                Column {
                    id: desk

                    required property var modelData
                    required property int index
                    readonly property var windows: CosmicWindows.windows.filter(w => !w.minimized && w.w > 0 && (w.ws >= 0 ? w.ws === index : (w.workspace_active === desk.modelData.active)))
                    readonly property real s: root.cardWidth / (Quickshell.screens[0]?.width ?? 1440)

                    spacing: 10

                    Rectangle {
                        id: card

                        width: root.cardWidth
                        height: root.cardWidth * root.ratio
                        radius: 16
                        color: "transparent"
                        clip: true
                        border.width: root.current === desk.index ? 3 : 1
                        border.color: root.current === desk.index ? Theme.accent : Theme.rimSoft
                        scale: cardArea.containsMouse ? 1.02 : 1

                        Behavior on scale {
                            Anim { duration: Theme.fast }
                        }

                        Sails {
                            anchors.fill: parent
                            anchors.margins: card.border.width
                            living: false
                        }

                        MouseArea {
                            id: cardArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(desk.index)
                        }

                        Repeater {
                            model: desk.windows

                            Rectangle {
                                id: win

                                required property var modelData

                                x: modelData.x * desk.s
                                y: modelData.y * desk.s
                                width: Math.max(24, modelData.w * desk.s)
                                height: Math.max(18, modelData.h * desk.s)
                                radius: 6
                                color: modelData.id === CosmicWindows.activeId ? (Theme.dark ? Qt.rgba(0.2, 0.19, 0.4, 0.92) : Qt.rgba(1, 1, 1, 0.92)) : (Theme.dark ? Qt.rgba(0.16, 0.15, 0.32, 0.85) : Qt.rgba(1, 1, 1, 0.75))
                                border.width: winArea.containsMouse ? 2 : 1
                                border.color: winArea.containsMouse ? Theme.accent : Theme.rimSoft

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    spacing: 2

                                    IconImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        implicitSize: Math.min(26, win.height * 0.4)
                                        source: QuillApps.iconForClass(win.modelData.app_id)
                                    }

                                    Text {
                                        visible: win.height > 46
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: win.modelData.title || QuillApps.nameForClass(win.modelData.app_id)
                                        elide: Text.ElideRight
                                        font.family: Theme.font
                                        font.pixelSize: 9
                                        color: Theme.textSecondary
                                    }
                                }

                                MouseArea {
                                    id: winArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        QuillState.close();
                                        CosmicWindows.activate(win.modelData.id);
                                    }
                                }
                            }
                        }
                    }

                    Kicker {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `Desk ${desk.index + 1}${desk.windows.length ? ` · ${desk.windows.length}` : ""}`
                        color: root.current === desk.index ? Theme.accent : Theme.textMuted
                    }
                }
            }
        }
    }
}
