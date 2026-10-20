pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.drift
import qs.drift.components
import qs.drift.surfaces
import qs.drift.surfaces.cc

// The Stage: one full-screen overlay window that holds every Drift pop-up surface. It exists only while a surface is
// open (or still animating out): it takes the keyboard, closes on a click outside the surface or on Esc, and blurs
// exactly the panes on show.
Scope {
    id: root

    readonly property bool wanted: DriftState.open !== ""
    property bool shown

    onWantedChanged: {
        if (wanted) {
            hideTimer.stop();
            shown = true;
        } else {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer

        interval: Theme.normal + 60
        onTriggered: root.shown = root.wanted
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            readonly property list<Item> surfaces: [gallery, cc, command, keys, today, session]

            screen: Quickshell.screens[0]
            WlrLayershell.namespace: "jellyface-drift-stage"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "transparent"

            BackgroundEffect.blurRegion: Theme.blur ? blur : null

            Region {
                id: blur

                regions: win.surfaces.filter(s => s.visible && s.blur).map(s => s.blur)
            }

            // a click anywhere outside a surface closes it
            MouseArea {
                anchors.fill: parent
                onClicked: DriftState.close()
            }

            Item {
                id: stage

                anchors.fill: parent
                focus: true

                Gallery {
                    id: gallery
                }

                ControlCenter {
                    id: cc
                }

                CommandBar {
                    id: command
                }

                KeysSheet {
                    id: keys
                }

                Today {
                    id: today
                }

                SessionMenu {
                    id: session
                }
            }
        }
    }
}
