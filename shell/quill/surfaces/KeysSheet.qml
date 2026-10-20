pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.quill
import qs.quill.components

// Every Quill shortcut on one glass sheet (Super+Shift+/). ↑↓ walk the list; Enter does what the selected row does.
Surface {
    id: root

    name: "keys"
    anchors.fill: parent

    property int current: -1

    readonly property var shortcuts: [
        {name: "Command bar", keys: ["Super", "Space"], run: () => QuillState.show("command")},
        {name: "Command bar", keys: ["Super"], run: () => QuillState.show("command")},
        {name: "Control Center", keys: ["Super", "C"], run: () => QuillState.show("cc")},
        {name: "Window hints", keys: ["Super", "E"], run: () => QuillState.show("hints")},
        {name: "Desks", keys: ["Super", "W"], run: () => QuillState.show("desks")},
        {name: "Clipboard history", keys: ["Super", "V"], run: () => QuillState.show("clipboard")},
        {name: "Appearance", keys: ["Super", "P"], run: () => QuillState.show("appearance")},
        {name: "Deep Focus", keys: ["Super", "Shift", "F"], run: () => DeepFocus.active ? DeepFocus.stop() : DeepFocus.start(0)},
        {name: "Lock", keys: ["Super", "L"], run: () => Session.lock()},
        {name: "This sheet", keys: ["Super", "Shift", "/"], run: () => QuillState.close()},
        {name: "Switch desk", keys: ["Super", "1 · 2 · 3"]},
        {name: "Move focus", keys: ["Super", "← → ↑ ↓"]},
        {name: "Close window", keys: ["Super", "Q"]}
    ]

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    onActiveChanged: current = -1

    Keys.onUpPressed: current = Math.max(0, current - 1)
    Keys.onDownPressed: current = Math.min(shortcuts.length - 1, current + 1)
    Keys.onReturnPressed: {
        const s = shortcuts[current];
        if (s?.run) {
            QuillState.close();
            s.run();
        }
    }

    Glass {
        id: sheet

        anchors.centerIn: parent
        width: 520
        height: col.implicitHeight + 40
        color: Theme.sheet
        scale: 0.97 + 0.03 * root.progress

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col

            x: 20
            y: 20
            width: parent.width - 40
            spacing: 2

            Kicker {
                text: "Keyboard first"
            }

            Label {
                text: "Everything has a shortcut."
                size: Theme.title
                bottomPadding: Theme.s3
            }

            Repeater {
                model: root.shortcuts

                Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    width: col.width
                    height: 40
                    radius: Theme.radiusRow
                    color: root.current === index ? Theme.accentSoft : rowArea.containsMouse ? Theme.tileHover : "transparent"
                    border.width: root.current === index ? 1 : 0
                    border.color: Theme.accent

                    Behavior on color {
                        ColorAnim { duration: Theme.fast }
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.current = row.index;
                            if (row.modelData.run) {
                                QuillState.close();
                                row.modelData.run();
                            }
                        }
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        secondary: root.current !== row.index
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: row.modelData.keys

                            Row {
                                id: k

                                required property string modelData
                                required property int index

                                spacing: 4

                                Label {
                                    visible: k.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "+"
                                    size: Theme.small
                                    muted: true
                                }

                                Keycap {
                                    key: k.modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
