pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.quill
import qs.quill.components
import qs.quill.surfaces
import qs.quill.surfaces.cc

// The Stage: one full-screen overlay window that holds every Quill pop-up surface. It is shown only while a surface
// is open (or still animating out): it takes the keyboard, closes on a click outside the surface or on Esc, and blurs
// exactly the panes on show.
Scope {
    id: root

    readonly property bool wanted: QuillState.open !== ""
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

    // built once and only shown and hidden, so a shortcut opens its surface at once (nothing to build or load)
    LazyLoader {
        active: true

        PanelWindow {
            id: win

            readonly property list<Item> surfaces: [gallery, cc, command, keys, today, session, appearance, hints, desks, clipboard, panel, lockpreview]

            visible: root.shown
            screen: Quickshell.screens[0]
            WlrLayershell.namespace: "jellyface-quill-stage"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "transparent"
            // the side bar stays clickable underneath (a status icon switches Control Center's page, as Classic's
            // pop-outs did); the keyboard stays here
            mask: Region {
                x: 68
                width: win.width - 68
                height: win.height
            }

            BackgroundEffect.blurRegion: Theme.blur ? blur : null

            Region {
                id: blur

                regions: win.surfaces.filter(s => s.visible && s.blur).map(s => s.blur)
            }

            // a click anywhere outside a surface closes it
            MouseArea {
                anchors.fill: parent
                onClicked: QuillState.close()
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

                Appearance {
                    id: appearance
                }

                Hints {
                    id: hints
                }

                Desks {
                    id: desks
                }

                ClipboardCarousel {
                    id: clipboard
                }

                RightPanel {
                    id: panel
                }

                LockPreview {
                    id: lockpreview
                }
            }
        }
    }
}
