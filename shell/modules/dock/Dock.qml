pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.utils

// JellyFace dock: a ghost badge in the top-left corner of the desktop that opens a 5x4 grid of apps on hover.
// It lives on the Bottom layer, so every window covers it. Apps come from ~/.config/caelestia/dock.json.
Scope {
    id: root

    readonly property int columns: 5
    readonly property int rows: 4
    property var apps: []

    // The windows that belong to an app. An app with a "match" (the Brave web apps) owns every window whose class
    // contains it; any other app owns the windows whose class is its desktop id or its StartupWMClass.
    function windowsOf(app: var): var {
        const entry = app.id ? DesktopEntries.heuristicLookup(app.id) : null;
        const ids = [app.id, entry?.startupClass, entry?.id].filter(x => x).map(x => x.toLowerCase().replace(/\.desktop$/, ""));
        if (app.id)
            ids.push(app.id.split(".").pop().toLowerCase()); // Flatpak/Electron apps often report just "obsidian"
        return CosmicWindows.windows.filter(w => {
            const cls = (w.app_id ?? "").toLowerCase();
            return app.match ? cls.includes(app.match.toLowerCase()) : ids.includes(cls);
        });
    }

    // Running app: focus its window (a further click cycles through its windows). Otherwise launch it.
    function open(app: var): void {
        const wins = windowsOf(app);
        if (wins.length > 0) {
            const at = wins.findIndex(w => w.id === CosmicWindows.activeId);
            CosmicWindows.activate(wins[(at + 1) % wins.length].id);
        } else if (app.command) {
            Quickshell.execDetached(["distrobox-host-exec", "sh", "-c", app.command]);
        } else {
            Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", app.id]);
        }
    }

    FileView {
        id: file

        path: `${Paths.config}/dock.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.apps = JSON.parse(text()).apps ?? [];
            } catch (e) {
                console.warn("dock.json is not valid JSON:", e);
            }
        }
    }

    StyledWindow {
        id: win

        screen: Quickshell.screens[0]
        name: "dock"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.left: true
        margins.top: Math.max(Tokens.padding.small, Config.border.thickness) + Tokens.padding.extraLargeIncreased
        margins.left: Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness) + Tokens.padding.extraLargeIncreased

        implicitWidth: panel.fullWidth
        implicitHeight: panel.fullHeight
        // only the dock itself takes the pointer; the rest of this (transparent) window is click-through
        mask: Region {
            item: panel
        }

        StyledRect {
            id: panel

            readonly property real tile: 64
            readonly property real gap: Tokens.spacing.medium
            readonly property real pad: Tokens.padding.large
            readonly property real badge: 80
            readonly property real fullWidth: root.columns * tile + (root.columns - 1) * gap + pad * 2
            readonly property real fullHeight: root.rows * tile + (root.rows - 1) * gap + pad * 2 + footer.implicitHeight + gap
            property bool expanded
            property string hovered

            color: Colours.tPalette.m3surface
            radius: expanded ? Tokens.rounding.extraLarge : Tokens.rounding.extraLarge * 1.5
            implicitWidth: expanded ? fullWidth : badge
            implicitHeight: expanded ? fullHeight : badge
            clip: true

            Behavior on implicitWidth {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on radius {
                Anim {}
            }

            Timer {
                id: collapseTimer

                interval: 400
                onTriggered: panel.expanded = false
            }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        collapseTimer.stop();
                        panel.expanded = true;
                    } else {
                        collapseTimer.restart();
                    }
                }
            }

            ColouredIcon {
                anchors.centerIn: parent
                source: `file://${Quickshell.shellPath("../assets/ghost.svg")}`
                implicitSize: panel.badge * 0.5
                colour: Colours.palette.m3primary
                opacity: panel.expanded ? 0 : 1

                Behavior on opacity {
                    Anim {}
                }
            }

            Item {
                x: panel.pad
                y: panel.pad
                width: panel.fullWidth - panel.pad * 2
                height: panel.fullHeight - panel.pad * 2
                opacity: panel.expanded ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {}
                }

                Grid {
                    id: grid

                    columns: root.columns
                    spacing: panel.gap

                    Repeater {
                        model: root.columns * root.rows

                        Tile {
                            required property int index

                            app: root.apps[index] ?? null
                        }
                    }
                }

                StyledText {
                    id: footer

                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.hovered || "JellyFace"
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    component Tile: StyledRect {
        id: tile

        property var app
        readonly property var entry: app?.id ? DesktopEntries.heuristicLookup(app.id) : null
        readonly property string label: app?.name ?? entry?.name ?? app?.id ?? ""
        readonly property var windows: app ? root.windowsOf(app) : []
        readonly property bool running: windows.length > 0
        readonly property bool focused: windows.some(w => w.id === CosmicWindows.activeId)

        implicitWidth: panel.tile
        implicitHeight: panel.tile
        radius: Tokens.rounding.large
        color: app ? Colours.tPalette.m3surfaceContainer : "transparent"

        StateLayer {
            anchors.fill: parent
            disabled: !tile.app
            radius: tile.radius
            color: Colours.palette.m3onSurface
            onClicked: root.open(tile.app)
            onContainsMouseChanged: panel.hovered = containsMouse ? tile.label : (panel.hovered === tile.label ? "" : panel.hovered)
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: panel.tile * 0.6
            visible: !!tile.app
            source: tile.app?.icon?.includes("/") ? `file://${Quickshell.shellPath("../" + tile.app.icon)}` : Quickshell.iconPath(tile.app?.icon ?? tile.entry?.icon ?? "", "application-x-executable")
        }

        // running indicator: a dot under the icon, a wider pill for the focused app
        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.padding.small / 2
            implicitWidth: tile.focused ? 14 : 5
            implicitHeight: 5
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary
            opacity: tile.running ? 1 : 0

            Behavior on implicitWidth {
                Anim {}
            }
            Behavior on opacity {
                Anim {}
            }
        }
    }
}
