pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.modules.launcher.services
import qs.services
import qs.utils

// JellyPanel: every installed app in a full-screen grid over the blurred desktop, in pages of 7 x 5, with a search
// pill on top and the dock left showing below. Super (or `jellyface ipc jellypanel toggle`) opens and closes it.
// Type to search, arrows move, Enter or a click opens the app, scroll or swipe for the next page, Esc or a click on
// the empty background closes.
// The window is built once and only shown and hidden, so opening is instant: no grid to build, no icons to load.
Scope {
    id: root

    readonly property int columns: 7
    readonly property int rows: 5
    readonly property int perPage: columns * rows
    // desktop ids of the apps installed on the host. The shell runs in a container whose own apps (cmake-gui,
    // avahi...) cannot be launched on the desktop, so only these are shown. Read at startup (so the first open never
    // shows the container's apps) and again each time JellyPanel opens (newly installed apps).
    property var hostIds: null
    property string hostKey

    Connections {
        function onOpenChanged(): void {
            if (!JellyPanel.open)
                return;
            hostApps.running = true;
            panel.item?.reset();
        }

        target: JellyPanel
    }

    Process {
        id: hostApps

        running: true
        command: ["sh", "-c", "ls -1 /run/host/usr/share/applications /run/host/usr/local/share/applications /run/host/var/lib/flatpak/exports/share/applications /run/host/var/lib/snapd/desktop/applications \"$HOME/.local/share/applications\" \"$HOME/.local/share/flatpak/exports/share/applications\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.split("\n").filter(l => l.endsWith(".desktop")).map(l => l.slice(0, -8)).sort();
                // only when apps were (un)installed: a new set rebuilds the whole grid
                if (ids.join("\n") !== root.hostKey) {
                    root.hostKey = ids.join("\n");
                    root.hostIds = new Set(ids);
                }
            }
        }
    }

    function onHost(entry: var): bool {
        return !hostIds || hostIds.has(entry.id) || hostIds.has(entry.id.replace(/\.desktop$/, ""));
    }

    LazyLoader {
        id: panel

        active: true

        StyledWindow {
            id: win

            // every app the desktop shows, A-Z; while searching, the matches best first
            readonly property var allApps: [...DesktopEntries.applications.values].filter(a => !a.noDisplay && root.onHost(a) && !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id)).sort((a, b) => a.name.localeCompare(b.name))
            readonly property var shown: search.text.trim() ? Apps.search(search.text.trim()).filter(a => !a.noDisplay && root.onHost(a)) : allApps
            readonly property int pageCount: Math.max(1, Math.ceil(shown.length / root.perPage))
            property int selected: -1 // keyboard selection (-1 = none); Enter opens it

            // each time JellyPanel opens: a fresh search on the first page, and the quick fade-and-settle
            function reset(): void {
                search.text = "";
                selected = -1;
                pages.positionViewAtBeginning();
                pages.currentIndex = 0;
                search.forceActiveFocus();
                openAnim.restart();
            }

            function launch(entry: var): void {
                if (!entry)
                    return;
                Apps.launch(entry);
                JellyPanel.open = false;
            }

            function select(i: int): void {
                if (shown.length === 0)
                    return;
                selected = Math.max(0, Math.min(shown.length - 1, i));
                pages.currentIndex = Math.floor(selected / root.perPage);
            }

            screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
            name: "jellypanel"
            visible: JellyPanel.open
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top // above windows and the bar; the dock moves to Overlay meanwhile
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            BackgroundEffect.blurRegion: wholeScreen

            Region {
                id: wholeScreen

                width: win.width
                height: win.height
            }

            // Frosted glass background: neutral translucent tone with subtle lighting depth over compositor blur
            Rectangle {
                id: veil

                readonly property real backdropLuma: Glass.backdrop ?? 0.3
                // In dark mode: neutral slate/graphite tone that adapts smoothly to backdrop brightness
                readonly property real baseLuma: Math.max(0.14, Math.min(0.24, 0.21 - backdropLuma * 0.05))
                readonly property real baseAlpha: Math.max(0.55, Math.min(0.68, 0.58 + backdropLuma * 0.10))
                readonly property color topColor: Colours.light
                    ? Qt.rgba(0.95, 0.96, 0.98, 0.72)
                    : Qt.rgba(baseLuma + 0.03, (baseLuma + 0.03) * 1.02, (baseLuma + 0.03) * 1.05, baseAlpha - 0.03)
                readonly property color bottomColor: Colours.light
                    ? Qt.rgba(0.89, 0.90, 0.93, 0.65)
                    : Qt.rgba(baseLuma - 0.02, (baseLuma - 0.02) * 1.02, (baseLuma - 0.02) * 1.05, baseAlpha + 0.03)

                anchors.fill: parent
                color: Colours.light
                    ? Qt.rgba(0.92, 0.93, 0.95, 0.68)
                    : Qt.rgba(baseLuma, baseLuma * 1.02, baseLuma * 1.05, baseAlpha)

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: veil.topColor
                    }
                    GradientStop {
                        position: 1.0
                        color: veil.bottomColor
                    }
                }

                GlassGrain {
                    grainOpacity: 0.025
                }
            }

            // open with a quick macOS-style zoom: the desktop dims and the grid settles in from slightly larger
            ParallelAnimation {
                id: openAnim

                NumberAnimation {
                    target: veil
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: content
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 160
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: content
                    property: "scale"
                    from: 1.03
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // a click on the empty background closes
            MouseArea {
                anchors.fill: parent
                onClicked: JellyPanel.open = false
            }

            Item {
                id: content

                anchors.fill: parent
                anchors.leftMargin: parent.width * 0.07
                anchors.rightMargin: parent.width * 0.07
                anchors.topMargin: Tokens.padding.extraLarge * 1.5
                // leave the dock its own strip at the bottom
                anchors.bottomMargin: 170


                SearchBar {
                    id: search

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 300
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small
                    placeholderText: Tr.tr("Search")

                    // a search selects its best match, so Enter opens it; clearing the search clears the selection
                    onTextChanged: {
                        win.selected = text.trim() && win.shown.length > 0 ? 0 : -1;
                        pages.currentIndex = 0;
                    }
                    Keys.onEscapePressed: {
                        if (text)
                            text = "";
                        else
                            JellyPanel.open = false;
                    }
                    Keys.onReturnPressed: win.launch(win.selected >= 0 ? win.shown[win.selected] : null)
                    Keys.onEnterPressed: win.launch(win.selected >= 0 ? win.shown[win.selected] : null)
                    Keys.onRightPressed: event => {
                        if (win.selected < 0 && cursorPosition < text.length) {
                            event.accepted = false;
                            return;
                        }
                        win.select(win.selected + 1);
                    }
                    Keys.onLeftPressed: event => {
                        if (win.selected < 0) {
                            event.accepted = false;
                            return;
                        }
                        win.select(win.selected - 1);
                    }
                    Keys.onDownPressed: win.select(win.selected < 0 ? 0 : win.selected + root.columns)
                    Keys.onUpPressed: win.select(win.selected - root.columns)
                    Keys.onTabPressed: win.select(win.selected + 1)
                    Keys.onBacktabPressed: win.select(win.selected - 1)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageDown)
                            pages.incrementCurrentIndex();
                        else if (event.key === Qt.Key_PageUp)
                            pages.decrementCurrentIndex();
                        else
                            return;
                        event.accepted = true;
                    }
                }

                StyledText {
                    anchors.centerIn: pages
                    visible: win.shown.length === 0
                    text: Tr.tr("No apps match \"%1\"").arg(search.text.trim())
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.large
                }

                // one page per 35 apps, side by side; pages turn through the scroll layer below, the dots or Page Up/Down
                ListView {
                    id: pages

                    anchors.top: search.bottom
                    anchors.topMargin: Tokens.padding.extraLarge * 1.5
                    anchors.bottom: dots.top
                    anchors.bottomMargin: Tokens.padding.large
                    anchors.left: parent.left
                    anchors.right: parent.right

                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 350
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    interactive: false
                    model: win.pageCount

                    delegate: Item {
                        id: page

                        required property int index

                        width: pages.width
                        height: pages.height

                        Grid {
                            anchors.fill: parent
                            columns: root.columns

                            Repeater {
                                model: win.shown.slice(page.index * root.perPage, (page.index + 1) * root.perPage)

                                AppTile {
                                    pageIndex: page.index
                                }
                            }
                        }
                    }
                }

                // Pages turn one at a time, only through this layer above the grid. It takes scroll events and nothing
                // else (no clicks, no hover), so the tiles under it still highlight and open; the list's own
                // pixel-by-pixel scrolling is off, as it fought the page turns.
                // Touchpad: one page per gesture (between the touchpad's own begin and end of scrolling), once the
                // fingers have travelled `swipe` pixels; momentum after the fingers lift is ignored. Fingers towards the
                // left or up = next page with natural scrolling (the touchpad's direction setting is respected).
                // Mouse wheel: one page per notch.
                MouseArea {
                    id: wheel

                    readonly property real swipe: 50
                    property real acc
                    property bool turned // this gesture already turned a page

                    anchors.fill: pages
                    z: 1
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: false

                    onWheel: event => {
                        if (event.phase === Qt.ScrollBegin || event.phase === Qt.ScrollEnd) {
                            acc = 0;
                            turned = false;
                            return;
                        }
                        if (event.phase === Qt.ScrollMomentum || turned)
                            return;
                        const touchpad = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0;
                        const d = touchpad ? event.pixelDelta : event.angleDelta;
                        const v = Math.abs(d.x) > Math.abs(d.y) ? d.x : d.y; // the stronger axis decides
                        acc += event.inverted ? -v : v; // now negative = towards the next page
                        if (Math.abs(acc) >= (touchpad ? swipe : 120)) {
                            if (acc < 0)
                                pages.incrementCurrentIndex();
                            else
                                pages.decrementCurrentIndex();
                            acc = 0;
                            // a mouse wheel has no gestures: every notch may turn a page
                            turned = touchpad && event.phase !== Qt.NoScrollPhase;
                        }
                    }
                }

                // page dots
                Row {
                    id: dots

                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.spacing.small
                    visible: win.pageCount > 1
                    height: 10

                    Repeater {
                        model: win.pageCount

                        StyledRect {
                            id: dot

                            required property int index

                            y: 1
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3onSurface
                            opacity: pages.currentIndex === index ? 0.95 : 0.35

                            Behavior on opacity {
                                Anim {}
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pages.currentIndex = dot.index
                            }
                        }
                    }
                }
            }

            component AppTile: Item {
                id: tile

                required property var modelData
                required property int index
                property int pageIndex
                readonly property int globalIndex: pageIndex * root.perPage + index
                readonly property bool isSelected: win.selected === globalIndex
                readonly property real iconSize: Math.min(width * 0.38, height * 0.46, 80)

                width: pages.width / root.columns
                height: pages.height / root.rows

                // hover / keyboard-selection frost behind the icon and label
                StyledRect {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Tokens.padding.medium, tile.iconSize * 1.7)
                    height: parent.height - Tokens.padding.medium
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3onSurface
                    opacity: tile.isSelected ? 0.14 : area.containsMouse ? 0.08 : 0

                    Behavior on opacity {
                        Anim {
                            duration: 120
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: tile.iconSize
                        source: Quickshell.iconPath(tile.modelData?.icon, "application-x-executable")
                        asynchronous: true
                        scale: area.pressed ? 0.9 : 1

                        Behavior on scale {
                            Anim {
                                duration: 120
                            }
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tile.width - Tokens.padding.medium * 2
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData?.name ?? ""
                        elide: Text.ElideRight
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.launch(tile.modelData)
                }
            }
        }
    }
}
