import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.drift
import qs.drift.components

// Volume and brightness changes (keys, scroll, another app): a small glass pill under the top bar with the level,
// for a second and a half. Not while Control Center is open (its sliders already show it).
Scope {
    id: root

    readonly property var monitor: Brightness.getMonitorForScreen(Quickshell.screens[0])
    property string kind // volume | brightness
    property bool shown
    property bool ready // not for the values read at start

    function show(k: string): void {
        if (!ready || DriftState.open === "cc")
            return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: hide

        interval: 1500
        onTriggered: root.shown = false
    }

    Connections {
        function onVolumeChanged(): void {
            root.show("volume");
        }

        function onMutedChanged(): void {
            root.show("volume");
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            root.show("brightness");
        }

        target: root.monitor
        ignoreUnknownSignals: true
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: root.shown || pill.opacity > 0
        WlrLayershell.namespace: "jellyface-drift-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        margins.top: 44
        implicitWidth: pill.width + 40
        implicitHeight: pill.height + 40
        color: "transparent"
        mask: Region {}

        BackgroundEffect.blurRegion: Theme.blur ? blur : null

        Region {
            id: blur

            BlurRegion {
                pane: pill.body
            }
        }

        Glass {
            id: pill

            readonly property real level: root.kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : (root.monitor?.brightness ?? 0)

            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            width: 260
            height: 44
            radius: 22
            color: Theme.sheet
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.92

            Behavior on opacity {
                Anim {}
            }
            Behavior on scale {
                Anim {}
            }

            Icon {
                id: glyph

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                name: root.kind === "volume" ? (Audio.muted ? "no_sound" : pill.level > 0.5 ? "volume_up" : "volume_down") : "light_mode"
                size: 18
            }

            Rectangle {
                anchors.left: glyph.right
                anchors.leftMargin: 12
                anchors.right: value.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Theme.well

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, pill.level))
                    height: parent.height
                    radius: 3
                    color: Theme.accent

                    Behavior on width {
                        Anim { duration: Theme.fast }
                    }
                }
            }

            Label {
                id: value

                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(pill.level * 100)}`
                size: Theme.small
                font.weight: Font.DemiBold
            }
        }
    }
}
