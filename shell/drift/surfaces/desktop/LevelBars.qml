import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.drift
import qs.drift.components

// Classic's right-edge volume and brightness bars, in Drift's glass: whenever the volume, the microphone or the
// brightness changes (keys, scrolling on the side bar, another app), tall sliders slide in at the right edge for a
// moment. Hovering keeps them; drag or scroll to adjust. Not while the right panel is open.
Scope {
    id: root

    readonly property var monitor: Brightness.getMonitorForScreen(Quickshell.screens[0])
    property bool shown
    property bool hovered
    property bool ready // not for the values read at start
    property bool showMic

    function show(mic: bool): void {
        if (!ready || DriftState.open === "panel")
            return;
        showMic = mic;
        shown = true;
        hide.restart();
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: hide

        interval: 1800
        onTriggered: {
            if (root.hovered)
                restart();
            else
                root.shown = false;
        }
    }

    Connections {
        function onVolumeChanged(): void {
            root.show(false);
        }

        function onMutedChanged(): void {
            root.show(false);
        }

        function onSourceVolumeChanged(): void {
            root.show(true);
        }

        function onSourceMutedChanged(): void {
            root.show(true);
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            root.show(false);
        }

        target: root.monitor
        ignoreUnknownSignals: true
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens[0]
        visible: root.shown || slide.running
        WlrLayershell.namespace: "jellyface-drift-levels"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors.right: true
        implicitWidth: pane.width + 30
        implicitHeight: pane.height + 40
        color: "transparent"
        mask: Region {
            item: pane
        }

        BackgroundEffect.blurRegion: Theme.blur ? blur : null

        Region {
            id: blur

            BlurRegion {
                pane: pane.body
            }
        }

        Glass {
            id: pane

            property real offset: root.shown ? 0 : width + 30

            x: parent.width - width - 10 + offset
            anchors.verticalCenter: parent.verticalCenter
            width: column.width + 20
            height: column.height + 20
            radius: 30
            color: Theme.sheet

            Behavior on offset {
                Anim {
                    id: slide

                    duration: Theme.slow
                }
            }

            HoverHandler {
                onHoveredChanged: root.hovered = hovered
            }

            Column {
                id: column

                anchors.centerIn: parent
                spacing: 10

                VSlider {
                    icon: Audio.muted ? "volume_off" : "volume_up"
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: v => {
                        Audio.setVolume(v);
                        hide.restart();
                    }
                }

                VSlider {
                    visible: root.showMic
                    icon: Audio.sourceMuted ? "mic_off" : "mic"
                    value: Audio.sourceMuted ? 0 : Audio.sourceVolume
                    onMoved: v => {
                        Audio.setSourceVolume(v);
                        hide.restart();
                    }
                }

                VSlider {
                    visible: !!root.monitor
                    icon: "light_mode"
                    value: root.monitor?.brightness ?? 0
                    onMoved: v => {
                        root.monitor?.setBrightness(Math.max(0.01, v));
                        hide.restart();
                    }
                }
            }
        }
    }
}
