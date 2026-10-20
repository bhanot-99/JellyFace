pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.quill
import qs.quill.components

// Quill's dock: a glass capsule of app icons at the bottom centre, from the same dock.json as Classic's dock.
// A dot under an app shows it is running (a longer accent bar: it has focus). Click opens or cycles its windows;
// right-click offers "Close windows" and "Remove from dock". The last button opens the command bar (every app).
//   always    stays up and windows keep clear of it
//   autohide  slides away while a window is on the desk; the bottom edge calls it back
//   off       never shown (Super+Space finds every app)
// Deep Focus and fullscreen windows hide it.
Scope {
    id: root

    readonly property string mode: QuillConfig.dock
    readonly property bool covered: CosmicWindows.windows.some(w => w.workspace_active && !w.minimized)
    property bool edge // the cursor is on the bottom edge
    property int menuIndex: -1
    readonly property bool wanted: mode !== "off" && !DeepFocus.active && !CosmicWindows.fullscreen && (mode === "always" || !covered || edge || hover.hovered || menuIndex >= 0)
    property bool shown: wanted

    readonly property int icon: 44
    readonly property int slot: 52
    readonly property int pad: 8

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

        interval: 450
        onTriggered: root.shown = root.wanted
    }

    // the bottom-edge trigger that calls an auto-hidden dock back. It stays up while the dock is out: a window that is
    // hidden never hears the cursor leave, so `edge` stayed true and the dock never went away again.
    PanelWindow {
        screen: Quickshell.screens[0]
        visible: root.mode === "autohide" && !DeepFocus.active && !CosmicWindows.fullscreen
        onVisibleChanged: if (!visible) root.edge = false
        WlrLayershell.namespace: "jellyface-quill-dock-edge"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        implicitWidth: capsule.width
        implicitHeight: 3
        color: "transparent"

        Item {
            anchors.fill: parent

            HoverHandler {
                onHoveredChanged: root.edge = hovered
            }
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens[0]
        visible: root.shown || slide.running
        WlrLayershell.namespace: "jellyface-quill-dock"
        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: root.mode === "always" && root.wanted ? capsule.height + 14 : 0
        anchors.bottom: true
        implicitWidth: Math.max(capsule.width + 40, 360)
        implicitHeight: capsule.height + 14 + 120 // room above for labels and the menu
        color: "transparent"
        mask: Region {
            Region { item: capsule }
            Region { item: menu.visible ? menu : null }
        }

        BackgroundEffect.blurRegion: Theme.blur ? blur : null

        Region {
            id: blur

            BlurRegion { pane: capsule.body }
            BlurRegion { pane: menu.visible ? menu.body : null }
        }

        Item {
            anchors.fill: parent

            HoverHandler {
                id: hover
            }
        }

        Glass {
            id: capsule

            property real lift: root.shown ? 0 : height + 20

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 10 + lift
            width: row.width + root.pad * 2
            height: root.slot + root.pad * 2
            radius: height / 2
            shadowStrength: 0.8

            Behavior on lift {
                Anim {
                    id: slide

                    duration: Theme.slow
                }
            }

            Row {
                id: row

                anchors.centerIn: parent

                Repeater {
                    model: QuillApps.dock

                    Item {
                        id: cell

                        required property var modelData
                        required property int index
                        readonly property var entry: QuillApps.entryOf(modelData)
                        readonly property var classes: QuillApps.classesOf(modelData, entry)
                        readonly property var windows: QuillApps.windowsOf(modelData, classes)
                        readonly property bool running: windows.length > 0
                        readonly property bool focused: windows.some(w => w.id === CosmicWindows.activeId)
                        readonly property string label: modelData.name ?? entry?.name ?? modelData.id ?? ""

                        width: root.slot
                        height: root.slot

                        IconImage {
                            id: img

                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: area.containsMouse ? -4 : 0
                            implicitSize: root.icon
                            source: QuillApps.iconOf(cell.modelData, cell.entry)
                            asynchronous: true
                            scale: area.pressed ? 0.9 : area.containsMouse ? 1.12 : 1

                            Behavior on scale {
                                Anim { duration: Theme.fast }
                            }
                            Behavior on anchors.verticalCenterOffset {
                                Anim { duration: Theme.fast }
                            }
                        }

                        Rectangle {
                            visible: cell.running
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -5
                            width: cell.focused ? 12 : 4
                            height: 4
                            radius: 2
                            color: cell.focused ? Theme.accent : Theme.textSecondary

                            Behavior on width {
                                Anim {}
                            }
                        }

                        // the name, above the icon while hovered
                        Rectangle {
                            visible: opacity > 0
                            opacity: area.containsMouse && root.menuIndex < 0 ? 1 : 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: root.pad + 12
                            width: tip.implicitWidth + 18
                            height: 26
                            radius: 13
                            color: Theme.sheet
                            border.width: 1
                            border.color: Theme.rimSoft

                            Behavior on opacity {
                                Anim { duration: Theme.fast }
                            }

                            Label {
                                id: tip

                                anchors.centerIn: parent
                                size: Theme.small
                                font.weight: Font.Medium
                                text: cell.label
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: e => {
                                if (e.button === Qt.RightButton) {
                                    root.menuIndex = root.menuIndex === cell.index ? -1 : cell.index;
                                    menu.anchorX = cell.mapToItem(win.contentItem, cell.width / 2, 0).x;
                                } else {
                                    root.menuIndex = -1;
                                    QuillApps.open(cell.modelData);
                                }
                            }
                        }
                    }
                }

                // divider and the "every app" button
                Item {
                    width: 17
                    height: root.slot

                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: root.slot * 0.6
                        color: Theme.divider
                    }
                }

                Item {
                    width: root.slot
                    height: root.slot

                    IconButton {
                        anchors.centerIn: parent
                        size: root.icon
                        icon: "apps"
                        onClicked: QuillState.toggle("command")
                    }
                }
            }
        }

        // right-click menu
        Glass {
            id: menu

            property real anchorX

            visible: root.menuIndex >= 0
            color: Theme.sheet
            radius: 16
            width: 200
            height: menuCol.implicitHeight + 12
            x: Math.max(8, Math.min(parent.width - width - 8, anchorX - width / 2))
            y: capsule.y - height - 10

            Column {
                id: menuCol

                anchors.fill: parent
                anchors.margins: 6

                ListRow {
                    width: parent.width
                    rowHeight: 36
                    icon: "close"
                    title: "Close windows"
                    dimmed: root.menuIndex < 0 || QuillApps.windowsOf(QuillApps.dock[root.menuIndex]).length === 0
                    onClicked: {
                        for (const w of QuillApps.windowsOf(QuillApps.dock[root.menuIndex]))
                            CosmicWindows.close(w.id);
                        root.menuIndex = -1;
                    }
                }

                ListRow {
                    width: parent.width
                    rowHeight: 36
                    icon: "keep_off"
                    title: "Remove from dock"
                    onClicked: {
                        QuillApps.remove(root.menuIndex);
                        root.menuIndex = -1;
                    }
                }
            }
        }
    }
}
