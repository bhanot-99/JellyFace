pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.drift
import qs.drift.components
import qs.drift.surfaces.dash

// The dashboard (rest the cursor on the top edge, like Classic's, or click the clock on the side bar): Classic's four
// tabs in Drift's look.
//   Dashboard    the date and calendar, events, weather, the system at a glance, media, quick actions
//   Media        the cover with a visualiser, seek bar, controls, players, synced lyrics
//   Performance  CPU, GPU, memory, storage, network, battery
//   Weather      now, the next hours, the week
// Tab / Shift+Tab or 1-4 switch tabs; the arrows work inside a tab (the calendar's day, the next track).
Surface {
    id: root

    name: "today"
    anchors.fill: parent

    readonly property var tabs: [home, media, performance, weather]
    readonly property Item tab: tabs[DriftState.dashTab] ?? home

    onActiveChanged: {
        if (active)
            home.reset();
        else
            visited = false;
    }

    Keys.onPressed: e => {
        const n = parseInt(e.text);
        if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
            DriftState.dashTab = (DriftState.dashTab + (e.key === Qt.Key_Backtab ? 3 : 1)) % 4;
        } else if (n >= 1 && n <= 4) {
            DriftState.dashTab = n - 1;
        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            tab.move(e.key === Qt.Key_Left ? -1 : e.key === Qt.Key_Right ? 1 : 0, e.key === Qt.Key_Up ? -1 : e.key === Qt.Key_Down ? 1 : 0);
        } else if (e.key === Qt.Key_Space && tab === media) {
            media.press();
        } else {
            return;
        }
        e.accepted = true;
    }

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

    // Like Classic's dashboard: once the cursor has been over the panel (or the strip above it, where it came down from
    // the top edge) and leaves, it closes after a moment. Opened from the clock, it stays until the cursor has visited.
    property bool visited

    Item {
        id: zone

        x: sheet.x
        width: sheet.width
        height: sheet.y + sheet.height + 6

        HoverHandler {
            id: zoneHover

            onHoveredChanged: {
                if (hovered) {
                    visit.restart();
                    leave.stop();
                } else {
                    visit.stop();
                    if (root.visited && root.active)
                        leave.restart();
                }
            }
        }
    }

    // a visit counts once the cursor has rested in the zone, after the panel finished opening: while it grows (or
    // changes height between tabs) the zone can sweep over a resting cursor and away again
    Timer {
        id: visit

        interval: 300
        onTriggered: {
            if (zoneHover.hovered && root.progress > 0.99)
                root.visited = true;
            else if (zoneHover.hovered)
                restart();
        }
    }

    Timer {
        id: leave

        interval: 350
        onTriggered: {
            if (!zoneHover.hovered && root.active)
                DriftState.close();
        }
    }

    Glass {
        id: sheet

        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: 860
        height: tabBar.height + 20 + root.tab.implicitHeight + 44
        color: Theme.sheet
        scale: 0.96 + 0.04 * root.progress
        transformOrigin: Item.Top

        Behavior on height {
            Anim { duration: Theme.slow }
        }

        MouseArea {
            anchors.fill: parent
        }

        Segmented {
            id: tabBar

            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            width: 520
            options: ["0", "1", "2", "3"]
            labels: ["Dashboard", "Media", "Performance", "Weather"]
            current: String(DriftState.dashTab)
            onPicked: o => DriftState.dashTab = parseInt(o)
        }

        Item {
            id: pages

            x: 20
            y: tabBar.y + tabBar.height + 20
            width: parent.width - 40
            height: root.tab.implicitHeight
            clip: true

            component Page: Item {
                id: page

                required property int index
                readonly property bool current: DriftState.dashTab === index

                width: pages.width
                height: pages.height
                visible: opacity > 0
                opacity: current ? 1 : 0
                x: current ? 0 : (index < DriftState.dashTab ? -40 : 40)

                Behavior on opacity {
                    Anim {}
                }
                Behavior on x {
                    Anim {}
                }
            }

            Page {
                index: 0

                DashHome {
                    id: home

                    width: parent.width
                }
            }

            Page {
                index: 1

                DashMedia {
                    id: media

                    width: parent.width
                    height: implicitHeight
                }
            }

            Page {
                index: 2

                DashPerformance {
                    id: performance

                    width: parent.width
                }
            }

            Page {
                index: 3

                DashWeather {
                    id: weather

                    width: parent.width
                    height: implicitHeight
                }
            }
        }
    }
}
