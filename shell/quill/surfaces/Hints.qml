pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.quill
import qs.quill.components

// Window hints (Super+E): every window on the desk gets a letter; press it to jump there. Esc cancels.
// (COSMIC tells the shell only about key presses, not releases, so it is a toggle rather than "hold Super".)
Surface {
    id: root

    name: "hints"
    anchors.fill: parent
    rise: 0

    readonly property string letters: "ASDFGHJKLQWERUIOPZXCVBNMTY"
    readonly property var windows: CosmicWindows.windows.filter(w => w.workspace_active && !w.minimized && w.w > 0 && w.h > 0).slice(0, letters.length)

    function jump(letter: string): bool {
        const i = letters.indexOf(letter.toUpperCase());
        const w = windows[i];
        if (i < 0 || !w)
            return false;
        QuillState.close();
        CosmicWindows.activate(w.id);
        return true;
    }

    Keys.onPressed: e => {
        if (e.text && root.jump(e.text))
            e.accepted = true;
    }

    // a light veil over the desk so the letters stand out
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }

    Repeater {
        model: root.windows

        Item {
            id: hint

            required property var modelData
            required property int index

            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 14
                color: Qt.alpha(Theme.accent, 0.08)
                border.width: 2
                border.color: Qt.alpha(Theme.accent, 0.7)
            }

            Glass {
                anchors.centerIn: parent
                // stacked windows share a centre: nudge each badge a little so none hide another
                anchors.horizontalCenterOffset: (hint.index % 3 - 1) * 18
                anchors.verticalCenterOffset: (Math.floor(hint.index / 3) % 2) * 18
                width: 132
                height: 112
                radius: 26
                color: Theme.sheet
                scale: 0.85 + 0.15 * root.progress

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 54
                        height: 54
                        radius: 16
                        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : "#FFFFFF"
                        border.width: 1
                        border.color: Theme.rimSoft

                        Text {
                            anchors.centerIn: parent
                            text: root.letters[hint.index]
                            font.family: Theme.font
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 16
                            source: QuillApps.iconForClass(hint.modelData.app_id)
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: QuillApps.nameForClass(hint.modelData.app_id) || hint.modelData.title
                            size: Theme.small
                            width: Math.min(implicitWidth, 96)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.jump(root.letters[hint.index])
                }
            }
        }
    }

    Pill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        height: 40
        padding: 18
        color: Theme.sheet

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.windows.length > 0 ? "Press a letter to jump to its window" : "No windows on this desk"
            font.weight: Font.Medium
        }

        Keycap {
            anchors.verticalCenter: parent.verticalCenter
            key: "esc"
        }
    }
}
