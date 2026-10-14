pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Jellyface.Components
import Jellyface.Config
import Jellyface.Services
import qs.components
import qs.components.containers
import qs.services
import qs.utils

// JellyFace desktop: a clock + weather card, system rings and a to-do list, an audio visualiser along the bottom edge, and
// a wallpaper that changes slowly. Everything sits on the Bottom layer (every window covers it) on blurred-glass cards.
// Settings: ~/.config/jellyface/desktop.json (default: config/desktop.json).
Scope {
    id: root

    property var widgets: ({
            clock: true,
            rings: true,
            todo: true,
            visualiser: true
        })
    property var wallpaperCycle: ({
            enabled: true,
            folder: "~/Pictures",
            minutes: 30,
            mode: "shuffle"
        })
    // the wallpaper COSMIC shows (read from its background config), blurred behind the cards
    property string wallpaper

    function nextWallpaper(): void {
        if (!cycle.running)
            cycle.running = true;
    }

    FileView {
        path: `${Paths.config}/desktop.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text());
                root.widgets = Object.assign({}, root.widgets, c.widgets ?? {});
                root.wallpaperCycle = Object.assign({}, root.wallpaperCycle, c.wallpaper ?? {});
            } catch (e) {
                console.warn("desktop.json is not valid JSON:", e);
            }
        }
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`}/cosmic/com.system76.CosmicBackground/v1/all`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = /source:\s*Path\("([^"]+)"\)/.exec(text());
            root.wallpaper = m ? m[1] : "";
        }
    }

    // ---- the slowly changing wallpaper ----
    Timer {
        interval: Math.max(1, root.wallpaperCycle.minutes) * 60000
        repeat: true
        running: root.wallpaperCycle.enabled
        onTriggered: root.nextWallpaper()
    }

    Process {
        id: cycle

        command: [Quickshell.shellPath("../scripts/wallpaper-cycle.sh"), root.wallpaperCycle.folder, root.wallpaperCycle.mode]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("wallpaper cycle:", text.trim())
        }
    }

    IpcHandler {
        function nextWallpaper(): void {
            root.nextWallpaper();
        }

        target: "desktop"
    }

    // ---- the window ----
    StyledWindow {
        id: win

        screen: Quickshell.screens[0]
        name: "desktop"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // the to-do list takes typing when you click it
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        // only the cards take the pointer; the rest of the desktop stays click-through
        mask: Region {
            regions: [
                Region {
                    item: clock.visible ? clock : null
                },
                Region {
                    item: rings.visible ? rings : null
                },
                Region {
                    item: todo.visible ? todo : null
                }
            ]
        }

        Item {
            id: scene

            readonly property real padLeft: Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness) + Tokens.padding.extraLargeIncreased * 1.5
            readonly property real padEdge: Math.max(Tokens.padding.small, Config.border.thickness) + Tokens.padding.extraLargeIncreased * 1.5

            anchors.fill: parent

            // the wallpaper, only to be blurred behind the cards
            Image {
                id: wall

                anchors.fill: parent
                visible: false
                source: root.wallpaper ? `file://${root.wallpaper}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 2048
            }

            // audio visualiser along the bottom edge, only while something plays
            Item {
                id: viz

                readonly property bool playing: root.widgets.visualiser && (Players.active?.isPlaying ?? false)

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: scene.padLeft
                anchors.rightMargin: scene.padEdge
                anchors.bottomMargin: scene.padEdge
                height: parent.height * 0.26
                opacity: playing ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: viz.opacity > 0

                    sourceComponent: Item {
                        ServiceRef {
                            service: Audio.cava
                        }

                        VisualiserBars {
                            id: bars

                            anchors.fill: parent
                            values: Audio.cava.values
                            primaryColor: Qt.alpha(Colours.palette.m3primary, 0.55)
                            secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.55)
                            rounding: Tokens.rounding.medium
                            spacing: Tokens.spacing.extraSmall
                            animationDuration: Tokens.anim.durations.normal
                        }

                        FrameAnimation {
                            running: viz.opacity > 0 && !bars.settled
                            onTriggered: bars.advance(frameTime)
                        }
                    }
                }
            }

            ClockCard {
                id: clock

                visible: root.widgets.clock
                wallpaper: wall
                x: scene.padLeft
                y: scene.padEdge
            }

            RingsCard {
                id: rings

                visible: root.widgets.rings
                wallpaper: wall
                x: scene.padLeft
                y: clock.visible ? clock.y + clock.height + Tokens.spacing.large : scene.padEdge
            }

            TodoCard {
                id: todo

                visible: root.widgets.todo
                wallpaper: wall
                x: scene.width - width - scene.padEdge
                y: scene.padEdge
            }
        }
    }
}
