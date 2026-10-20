pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.quill
import qs.quill.components

// The power menu: Lock · Sleep · Restart · Shut down · Log out as glass tiles. ←/→ choose, Enter runs. Restart,
// shut down and log out ask once more ("Press again"), so a stray click never ends the session.
Surface {
    id: root

    name: "session"
    anchors.fill: parent

    property int current: 0
    property int armed: -1

    readonly property var choices: [
        {label: "Lock", icon: "lock", run: () => Session.lock()},
        {label: "Sleep", icon: "bedtime", run: () => Session.sleep()},
        {label: "Restart", icon: "restart_alt", confirm: true, run: () => Session.restart()},
        {label: "Shut down", icon: "power_settings_new", confirm: true, run: () => Session.shutdown()},
        {label: "Log out", icon: "logout", confirm: true, run: () => Session.logout()}
    ]

    function choose(i: int): void {
        current = i;
        const c = choices[i];
        if (c.confirm && armed !== i) {
            armed = i;
            disarm.restart();
            return;
        }
        QuillState.close();
        c.run();
    }

    onActiveChanged: {
        current = 0;
        armed = -1;
    }

    Keys.onLeftPressed: current = Math.max(0, current - 1)
    Keys.onRightPressed: current = Math.min(choices.length - 1, current + 1)
    Keys.onReturnPressed: choose(current)
    Keys.onEnterPressed: choose(current)

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.armed = -1
    }

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    Glass {
        id: sheet

        anchors.centerIn: parent
        width: row.width + 48
        height: row.height + 96
        color: Theme.sheet
        scale: 0.96 + 0.04 * root.progress

        MouseArea {
            anchors.fill: parent
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 22
            text: root.armed >= 0 ? `Press ${root.choices[root.armed].label} again to confirm` : `See you soon`
            size: Theme.heading
            font.weight: Font.Medium
            color: root.armed >= 0 ? Theme.warn : Theme.text
        }

        Row {
            id: row

            anchors.horizontalCenter: parent.horizontalCenter
            y: 66
            spacing: 12

            Repeater {
                model: root.choices

                Tile {
                    id: tile

                    required property var modelData
                    required property int index

                    width: 112
                    height: 112
                    focused: root.current === index
                    selected: root.armed === index
                    onClicked: root.choose(index)

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 48
                            height: 48
                            radius: 24
                            color: root.armed === tile.index ? Theme.warn : root.current === tile.index ? Theme.accent : Theme.well

                            Behavior on color {
                                ColorAnim { duration: Theme.fast }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: tile.modelData.icon
                                size: 22
                                color: root.current === tile.index || root.armed === tile.index ? "#FFFFFF" : Theme.text
                            }
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.label
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
