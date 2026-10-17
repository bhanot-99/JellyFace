pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

// Mission Control / Exposé Workspace Viewer:
// Faithful to the official COSMIC Workspaces Overview architecture:
// 1. Top Workspace Bar: Displays full miniature desktop panels for all workspaces
//    (with real desktop wallpaper, proportional window shapes, and active highlights).
// 2. Main Center Canvas: Displays all applications in the currently opened workspace
//    as full-size 16:10 live viewport cards with rich contextual UI skeletons,
//    titlebars, icons, and spring hover physics.
// 3. Real-Time Search: Instant live filtering (⌘K or /).
// 4. Quick Look Modal: Press Space to expand any window into an enlarged inspection modal.
Scope {
    id: root

    property string searchQuery: ""
    property var quickLookWindow: null

    // Total non-minimized windows across all workspaces
    readonly property int totalWindowCount: CosmicWindows.windows.filter(w => !w.minimized).length

    // Helper: list windows belonging to a specific workspace index
    function getWindowsForWorkspace(wsIndex: int): var {
        return CosmicWindows.windows.filter(w => {
            if (w.minimized)
                return false;
            if (w.workspace !== undefined && w.workspace >= 0)
                return w.workspace === wsIndex;
            return w.workspace_active && wsIndex === CosmicWs.activeIndex;
        });
    }

    // Helper: test if window matches search query
    function isWindowMatch(w: var): bool {
        if (!searchQuery || searchQuery.trim().length === 0)
            return true;
        const q = searchQuery.trim().toLowerCase();
        const t = (w.title || "").toLowerCase();
        const a = (w.app_id || "").toLowerCase();
        return t.includes(q) || a.includes(q);
    }

    // Categorize application type for realistic preview UI skeleton inside window cards
    function getAppCategory(appId: string, title: string): string {
        const s = ((appId || "") + " " + (title || "")).toLowerCase();
        if (s.includes("term") || s.includes("alacritty") || s.includes("kitty") || s.includes("code") || s.includes("nvim") || s.includes("vim") || s.includes("bash") || s.includes("fish"))
            return "terminal";
        if (s.includes("brave") || s.includes("firefox") || s.includes("chrome") || s.includes("chromium") || s.includes("browser") || s.includes("zen") || s.includes("pinterest"))
            return "browser";
        if (s.includes("vlc") || s.includes("spotify") || s.includes("media") || s.includes("mpv") || s.includes("music") || s.includes("video") || s.includes("food wars"))
            return "media";
        if (s.includes("files") || s.includes("nautilus") || s.includes("thunar") || s.includes("folder"))
            return "files";
        return "generic";
    }

    StyledWindow {
        id: win

        // Currently viewed/opened workspace index
        property int selectedWsIndex: Math.max(0, CosmicWs.activeIndex)
        property int selectedWinIndex: 0
        property string closingWindowId: ""

        readonly property real displayW: win.screen?.width ?? 1920
        readonly property real displayH: win.screen?.height ?? 1200
        readonly property real displayRatio: displayW / Math.max(1, displayH)

        // Windows in the currently opened workspace
        readonly property var currentWsWindows: root.getWindowsForWorkspace(CosmicWs.list[win.selectedWsIndex]?.i ?? win.selectedWsIndex)

        // Windows filtered by search query
        readonly property var displayedWindows: {
            if (!root.searchQuery || root.searchQuery.trim().length === 0)
                return currentWsWindows;
            return currentWsWindows.filter(w => root.isWindowMatch(w));
        }

        // Auto-fit grid columns for window cards (up to 4 max)
        readonly property int gridCols: Math.min(4, Math.max(1, displayedWindows.length))

        function focusWindow(w: var): void {
            if (!w)
                return;
            root.quickLookWindow = null;
            root.searchQuery = "";
            CosmicWindows.activate(w.id);
            Overview.open = false;
        }

        function openWorkspace(wsIndex: int): void {
            if (wsIndex >= 0 && wsIndex < CosmicWs.list.length) {
                win.selectedWsIndex = wsIndex;
                win.selectedWinIndex = 0;
                CosmicWs.activate(CosmicWs.list[wsIndex].i);
            }
        }

        screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
        name: "window-overview"
        visible: Overview.open
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

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

        onVisibleChanged: {
            if (visible) {
                win.selectedWsIndex = Math.max(0, CosmicWs.activeIndex);
                win.selectedWinIndex = 0;
                root.searchQuery = "";
                root.quickLookWindow = null;
                keyController.forceActiveFocus();
            } else {
                root.quickLookWindow = null;
                root.searchQuery = "";
            }
        }

        // =========================================================================
        // VISUAL FOUNDATION: Obsidian Canvas & Top Radial Lighting Cone
        // =========================================================================
        Rectangle {
            id: veil

            anchors.fill: parent
            color: Qt.rgba(0.03, 0.035, 0.045, 0.88)

            Shape {
                id: ambientLightCone

                anchors.fill: parent
                opacity: 0.35

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"

                    fillGradient: RadialGradient {
                        centerX: win.width / 2
                        centerY: 0
                        centerRadius: win.width * 0.48
                        focalX: centerX
                        focalY: 0
                        focalRadius: 0

                        GradientStop { position: 0.0; color: Qt.rgba(0.40, 0.50, 0.70, 0.30) }
                        GradientStop { position: 0.3; color: Qt.rgba(0.20, 0.25, 0.38, 0.14) }
                        GradientStop { position: 0.7; color: Qt.rgba(0.10, 0.12, 0.20, 0.04) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }

                    startX: 0
                    startY: 0
                    PathLine { x: win.width; y: 0 }
                    PathLine { x: win.width; y: win.height }
                    PathLine { x: 0; y: win.height }
                    PathLine { x: 0; y: 0 }
                }
            }
        }

        // Dismiss overview on empty backdrop click
        MouseArea {
            anchors.fill: parent
            z: 1
            onClicked: Overview.open = false
        }

        // =========================================================================
        // KEYBOARD-FIRST NAVIGATION CONTROLLER
        // =========================================================================
        Item {
            id: keyController

            anchors.fill: parent
            focus: win.visible
            z: 2

            Keys.onEscapePressed: {
                if (root.quickLookWindow)
                    root.quickLookWindow = null;
                else if (root.searchQuery.length > 0)
                    root.searchQuery = "";
                else
                    Overview.open = false;
            }

            Keys.onReturnPressed: {
                if (root.quickLookWindow) {
                    win.focusWindow(root.quickLookWindow);
                } else if (win.displayedWindows.length > 0 && win.selectedWinIndex >= 0 && win.selectedWinIndex < win.displayedWindows.length) {
                    win.focusWindow(win.displayedWindows[win.selectedWinIndex]);
                } else {
                    win.openWorkspace(win.selectedWsIndex);
                    Overview.open = false;
                }
            }

            Keys.onEnterPressed: {
                if (root.quickLookWindow) {
                    win.focusWindow(root.quickLookWindow);
                } else if (win.displayedWindows.length > 0 && win.selectedWinIndex >= 0 && win.selectedWinIndex < win.displayedWindows.length) {
                    win.focusWindow(win.displayedWindows[win.selectedWinIndex]);
                } else {
                    win.openWorkspace(win.selectedWsIndex);
                    Overview.open = false;
                }
            }

            Keys.onSpacePressed: {
                if (root.quickLookWindow) {
                    root.quickLookWindow = null;
                } else if (win.displayedWindows.length > 0 && win.selectedWinIndex >= 0 && win.selectedWinIndex < win.displayedWindows.length) {
                    root.quickLookWindow = win.displayedWindows[win.selectedWinIndex];
                }
            }

            Keys.onLeftPressed: {
                if (win.displayedWindows.length > 0 && win.selectedWinIndex > 0) {
                    win.selectedWinIndex--;
                } else {
                    const totalWs = CosmicWs.list.length;
                    if (totalWs > 0) {
                        const prevIdx = Math.max(0, win.selectedWsIndex - 1);
                        win.openWorkspace(prevIdx);
                    }
                }
            }

            Keys.onRightPressed: {
                if (win.displayedWindows.length > 0 && win.selectedWinIndex < win.displayedWindows.length - 1) {
                    win.selectedWinIndex++;
                } else {
                    const totalWs = CosmicWs.list.length;
                    if (totalWs > 0) {
                        const nextIdx = Math.min(totalWs - 1, win.selectedWsIndex + 1);
                        win.openWorkspace(nextIdx);
                    }
                }
            }

            Keys.onUpPressed: {
                if (win.displayedWindows.length > 0)
                    win.selectedWinIndex = Math.max(0, win.selectedWinIndex - win.gridCols);
            }

            Keys.onDownPressed: {
                if (win.displayedWindows.length > 0)
                    win.selectedWinIndex = Math.min(win.displayedWindows.length - 1, win.selectedWinIndex + win.gridCols);
            }

            Keys.onTabPressed: {
                if (win.displayedWindows.length > 0)
                    win.selectedWinIndex = (win.selectedWinIndex + 1) % win.displayedWindows.length;
            }

            Keys.onBacktabPressed: {
                if (win.displayedWindows.length > 0)
                    win.selectedWinIndex = (win.selectedWinIndex - 1 + win.displayedWindows.length) % win.displayedWindows.length;
            }

            Keys.onPressed: event => {
                // Workspace jumps 1..9: switches to that workspace and displays its apps
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const wsIdx = event.key - Qt.Key_1;
                    if (wsIdx < CosmicWs.list.length) {
                        win.openWorkspace(wsIdx);
                        event.accepted = true;
                    }
                } else if ((event.modifiers & Qt.ControlModifier && event.key === Qt.Key_K) || event.key === Qt.Key_Slash) {
                    searchInput.forceActiveFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_W && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ControlModifier)) {
                    if (win.displayedWindows.length > 0 && win.displayedWindows[win.selectedWinIndex]) {
                        CosmicWindows.close(win.displayedWindows[win.selectedWinIndex].id);
                        event.accepted = true;
                    }
                }
            }
        }

        // =========================================================================
        // MAIN CONTENT CONTAINER
        // =========================================================================
        Item {
            id: mainContainer

            anchors.fill: parent
            anchors.margins: 24
            z: 10

            // ---------------------------------------------------------------------
            // 1. TOP BAR: Title & Real-Time Search Filter
            // ---------------------------------------------------------------------
            RowLayout {
                id: topBar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                spacing: 16

                // Left Metadata Status Pill
                Rectangle {
                    implicitHeight: 38
                    implicitWidth: leftRow.implicitWidth + 24
                    radius: 19
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    GlassBevel { radius: 19 }

                    RowLayout {
                        id: leftRow

                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "#30D158"

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                            }
                        }

                        StyledText {
                            text: Tr.tr("Mission Control")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: "#f4f4f5"
                        }

                        StyledText {
                            text: `·  ${CosmicWs.list.length} ${Tr.tr("Workspaces")}  ·  ${root.totalWindowCount} ${Tr.tr("Windows")}`
                            font.pixelSize: 12
                            color: "#71717a"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right Search Capsule (⌘K / Quick Filter)
                Rectangle {
                    id: searchCapsule

                    implicitHeight: 38
                    implicitWidth: searchInput.activeFocus || root.searchQuery.length > 0 ? 260 : 190
                    radius: 19
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: searchInput.activeFocus ? "#60a5fa" : Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    Behavior on implicitWidth {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    GlassBevel { radius: 19 }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialIcon {
                            text: "search"
                            color: searchInput.activeFocus ? "#60a5fa" : "#71717a"
                            fontStyle: Tokens.font.icon.medium
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextInput {
                            id: searchInput

                            Layout.fillWidth: true
                            text: root.searchQuery
                            onTextChanged: root.searchQuery = text
                            color: "#f4f4f5"
                            font.pixelSize: 12
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true

                            Keys.onEscapePressed: {
                                if (text.length > 0)
                                    text = "";
                                keyController.forceActiveFocus();
                            }

                            Keys.onReturnPressed: {
                                keyController.forceActiveFocus();
                            }

                            Keys.onDownPressed: {
                                keyController.forceActiveFocus();
                            }

                            Text {
                                anchors.fill: parent
                                text: "Filter windows..."
                                color: "#52525b"
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }

                        // Clear search or shortcut badge
                        Item {
                            implicitWidth: 30
                            implicitHeight: 20
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                visible: searchInput.text.length === 0

                                StyledText {
                                    anchors.centerIn: parent
                                    text: "⌘K"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: "#71717a"
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: clearMouse.containsMouse ? "#f4f4f5" : "#71717a"
                                fontStyle: Tokens.font.icon.small
                                visible: searchInput.text.length > 0

                                MouseArea {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = "";
                                        keyController.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------------------
            // 2. TOP WORKSPACE STRIP (Real Desktop Miniature Panels - COSMIC workspace_bar)
            // ---------------------------------------------------------------------
            Item {
                id: workspaceStrip

                anchors.top: topBar.bottom
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 114

                Flickable {
                    id: stripFlickable

                    anchors.centerIn: parent
                    width: Math.min(parent.width, stripRow.implicitWidth)
                    height: 114
                    contentWidth: stripRow.implicitWidth
                    contentHeight: 114
                    clip: false
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: stripRow

                        spacing: 16
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: CosmicWs.list.length > 0 ? CosmicWs.list : [{ i: 0, name: "1", active: true }]

                            // Miniature Desktop Panel for this workspace
                            Rectangle {
                                id: miniDesktopCard

                                required property var modelData
                                required property int index

                                readonly property bool isSelected: win.selectedWsIndex === miniDesktopCard.index
                                readonly property bool isCurrentActive: (CosmicWs.activeIndex === miniDesktopCard.index) || (miniDesktopCard.modelData && miniDesktopCard.modelData.active)
                                readonly property var wsWins: root.getWindowsForWorkspace(miniDesktopCard.modelData.i)

                                width: 172
                                height: 108
                                radius: 10
                                clip: true
                                color: "#0c0d12"
                                border.width: miniDesktopCard.isSelected ? 2 : 1
                                border.color: miniDesktopCard.isSelected ? "#60a5fa" : (miniDesktopCard.isCurrentActive ? Qt.rgba(0.40, 0.65, 1.0, 0.45) : Qt.rgba(1.0, 1.0, 1.0, 0.10))

                                Behavior on border.color {
                                    ColorAnimation { duration: 180 }
                                }

                                transform: [
                                    Translate {
                                        y: miniDesktopMouse.containsMouse ? -4 : (miniDesktopCard.isSelected ? -2 : 0)
                                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    },
                                    Scale {
                                        origin.x: miniDesktopCard.width / 2
                                        origin.y: miniDesktopCard.height / 2
                                        xScale: miniDesktopMouse.containsMouse ? 1.03 : (miniDesktopCard.isSelected ? 1.02 : 1.0)
                                        yScale: xScale
                                        Behavior on xScale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    }
                                ]

                                // Real Desktop Wallpaper
                                CachingImage {
                                    anchors.fill: parent
                                    path: Wallpapers.current || Wallpapers.fallback
                                    opacity: 0.85
                                }

                                // Dark frosted glass tint for contrast
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(0.06, 0.07, 0.09, 0.45)
                                }

                                GlassBevel { radius: 10 }

                                // Proportional mini windows layout inside desktop thumbnail
                                Item {
                                    id: miniLayoutArea

                                    anchors.fill: parent
                                    readonly property real sX: miniLayoutArea.width / win.displayW
                                    readonly property real sY: miniLayoutArea.height / win.displayH

                                    Repeater {
                                        model: miniDesktopCard.wsWins

                                        Rectangle {
                                            required property var modelData
                                            required property int index

                                            readonly property int tw: (modelData.w > 0) ? Math.max(20, Math.round(modelData.w * miniLayoutArea.sX)) : 30
                                            readonly property int th: (modelData.h > 0) ? Math.max(14, Math.round(modelData.h * miniLayoutArea.sY)) : 20
                                            readonly property int tx: (modelData.w > 0) ? Math.round(modelData.x * miniLayoutArea.sX) : 10
                                            readonly property int ty: (modelData.h > 0) ? Math.round(modelData.y * miniLayoutArea.sY) : 10

                                            x: Math.max(0, Math.min(miniLayoutArea.width - width, tx))
                                            y: Math.max(0, Math.min(miniLayoutArea.height - height, ty))
                                            width: tw
                                            height: th
                                            radius: 3
                                            color: modelData.activated ? Qt.rgba(0.24, 0.40, 0.65, 0.85) : Qt.rgba(0.12, 0.14, 0.18, 0.80)
                                            border.width: 1
                                            border.color: modelData.activated ? "#60a5fa" : Qt.rgba(1.0, 1.0, 1.0, 0.20)
                                        }
                                    }
                                }

                                // Workspace Label Badge at bottom
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 24
                                    color: Qt.rgba(0.04, 0.05, 0.07, 0.85)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 4

                                        Rectangle {
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: miniDesktopCard.isCurrentActive ? "#30D158" : (miniDesktopCard.isSelected ? "#60a5fa" : "#71717a")
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: (miniDesktopCard.modelData.name && miniDesktopCard.modelData.name.length > 0) ? `WS ${miniDesktopCard.modelData.name}` : `WS ${miniDesktopCard.index + 1}`
                                            font.pixelSize: 10
                                            font.weight: miniDesktopCard.isSelected ? Font.DemiBold : Font.Normal
                                            color: miniDesktopCard.isSelected ? "#f4f4f5" : "#a1a1aa"
                                        }

                                        StyledText {
                                            text: `${miniDesktopCard.wsWins.length}`
                                            font.pixelSize: 10
                                            color: "#71717a"
                                        }
                                    }
                                }

                                // Click to select/switch this workspace
                                MouseArea {
                                    id: miniDesktopMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.openWorkspace(miniDesktopCard.index);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------------------
            // 3. MAIN CENTER CANVAS: APPS IN THE OPEN WORKSPACE (COSMIC toplevels)
            // ---------------------------------------------------------------------
            Item {
                id: mainAppsCanvas

                anchors.top: workspaceStrip.bottom
                anchors.bottom: bottomLegendBar.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16
                anchors.bottomMargin: 14

                // Current Workspace Header & Info
                RowLayout {
                    id: currentWsHeader

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 28
                    spacing: 10

                    Rectangle {
                        implicitWidth: wsCurBadge.implicitWidth + 16
                        implicitHeight: 24
                        radius: 12
                        color: Qt.rgba(0.24, 0.40, 0.65, 0.35)
                        border.width: 1
                        border.color: Qt.rgba(0.40, 0.65, 1.0, 0.45)

                        StyledText {
                            id: wsCurBadge
                            anchors.centerIn: parent
                            text: {
                                const wsObj = CosmicWs.list[win.selectedWsIndex];
                                const wsName = (wsObj && wsObj.name && wsObj.name.length > 0) ? wsObj.name : `${win.selectedWsIndex + 1}`;
                                return `Workspace ${wsName}`;
                            }
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: "#93c5fd"
                        }
                    }

                    StyledText {
                        text: `·  ${win.displayedWindows.length} ${win.displayedWindows.length === 1 ? "window open" : "windows open"}`
                        font.pixelSize: 12
                        color: "#a1a1aa"
                    }
                }

                // Window Cards Scrollable Grid
                Flickable {
                    id: cardsFlickable

                    anchors.top: currentWsHeader.bottom
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 12
                    width: Math.min(parent.width, cardsGrid.implicitWidth)
                    contentWidth: cardsGrid.implicitWidth
                    contentHeight: cardsGrid.implicitHeight
                    clip: false
                    boundsBehavior: Flickable.StopAtBounds

                    Grid {
                        id: cardsGrid

                        columns: win.gridCols
                        spacing: 24
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: win.displayedWindows

                            // 16:10 Full Window Viewport Card
                            Item {
                                id: cardWrapper

                                required property var modelData
                                required property int index

                                readonly property bool isSelected: win.selectedWinIndex === cardWrapper.index
                                readonly property bool isClosing: win.closingWindowId === cardWrapper.modelData.id.toString()
                                readonly property string category: root.getAppCategory(modelData.app_id, modelData.title)

                                width: 340
                                height: 226

                                opacity: isClosing ? 0.0 : 1.0
                                scale: isClosing ? 0.90 : 1.0

                                Behavior on opacity {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                                Behavior on scale {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                // Spring-like hover physics
                                transform: [
                                    Translate {
                                        id: cardTrans
                                        y: cardArea.containsMouse ? -5 : (cardWrapper.isSelected ? -3 : 0)
                                        Behavior on y {
                                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                        }
                                    },
                                    Scale {
                                        id: cardScale
                                        origin.x: cardWrapper.width / 2
                                        origin.y: cardWrapper.height / 2
                                        xScale: cardArea.containsMouse ? 1.018 : (cardWrapper.isSelected ? 1.01 : 1.0)
                                        yScale: xScale
                                        Behavior on xScale {
                                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                        }
                                    }
                                ]

                                Rectangle {
                                    id: cardRect

                                    anchors.fill: parent
                                    radius: 12
                                    clip: true
                                    color: cardArea.containsMouse ? Qt.rgba(0.11, 0.11, 0.14, 0.75) : Qt.rgba(0.07, 0.07, 0.09, 0.65)
                                    border.width: cardWrapper.isSelected ? 2 : 1
                                    border.color: cardWrapper.isSelected ? "#60a5fa" : (cardArea.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.22) : Qt.rgba(1.0, 1.0, 1.0, 0.08))

                                    Behavior on border.color {
                                        ColorAnimation { duration: 180 }
                                    }

                                    GlassBevel { radius: 12 }

                                    Column {
                                        anchors.fill: parent

                                        // -------------------------------------------------------------
                                        // Header Bar: Icon (16x16) + Window Title + Dismiss (x) Button
                                        // -------------------------------------------------------------
                                        Rectangle {
                                            id: headerBar

                                            width: parent.width
                                            height: 36
                                            color: Qt.rgba(1.0, 1.0, 1.0, 0.03)

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 10
                                                spacing: 8

                                                IconImage {
                                                    implicitSize: 16
                                                    source: Quickshell.iconPath(cardWrapper.modelData.app_id || "", "application-x-executable")
                                                    asynchronous: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 0

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: cardWrapper.modelData.title || cardWrapper.modelData.app_id || "Window"
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                        color: "#f4f4f5"
                                                        elide: Text.ElideRight
                                                    }

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: cardWrapper.modelData.app_id || "Application"
                                                        font.pixelSize: 9
                                                        color: "#71717a"
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                // Dismiss (x) button revealed on hover
                                                Rectangle {
                                                    id: dismissBtn

                                                    implicitWidth: 20
                                                    implicitHeight: 20
                                                    radius: 10
                                                    color: dismissMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                                    opacity: cardArea.containsMouse ? 1.0 : 0.0
                                                    Layout.alignment: Qt.AlignVCenter

                                                    Behavior on opacity {
                                                        NumberAnimation { duration: 150 }
                                                    }

                                                    MaterialIcon {
                                                        anchors.centerIn: parent
                                                        text: "close"
                                                        color: dismissMouse.containsMouse ? "#ef4444" : "#a1a1aa"
                                                        fontStyle: Tokens.font.icon.small
                                                    }

                                                    MouseArea {
                                                        id: dismissMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            win.closingWindowId = cardWrapper.modelData.id.toString();
                                                            dismissTimer.start();
                                                        }

                                                        Timer {
                                                            id: dismissTimer
                                                            interval: 180
                                                            onTriggered: {
                                                                CosmicWindows.close(cardWrapper.modelData.id);
                                                                win.closingWindowId = "";
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // -------------------------------------------------------------
                                        // 16:10 High-Fidelity Preview Viewport (Contextual UI Skeleton)
                                        // -------------------------------------------------------------
                                        Rectangle {
                                            id: previewViewport

                                            width: parent.width
                                            height: 160
                                            color: "#090a0d"
                                            clip: true

                                            // Vignette Inner Gradient
                                            Rectangle {
                                                anchors.fill: parent
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.15) }
                                                    GradientStop { position: 0.5; color: "transparent" }
                                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.40) }
                                                }
                                            }

                                            // Contextual Skeleton Selector
                                            Loader {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                sourceComponent: {
                                                    switch (cardWrapper.category) {
                                                    case "terminal":
                                                        return terminalSkeleton;
                                                    case "browser":
                                                        return browserSkeleton;
                                                    case "media":
                                                        return mediaSkeleton;
                                                    default:
                                                        return genericSkeleton;
                                                    }
                                                }
                                            }

                                            // Quick Look spacebar hint on hover
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right
                                                anchors.margins: 8
                                                implicitHeight: 18
                                                implicitWidth: qlHintRow.implicitWidth + 8
                                                radius: 4
                                                color: Qt.rgba(0, 0, 0, 0.65)
                                                opacity: cardArea.containsMouse ? 1.0 : 0.0

                                                Behavior on opacity {
                                                    NumberAnimation { duration: 150 }
                                                }

                                                Row {
                                                    id: qlHintRow
                                                    anchors.centerIn: parent
                                                    spacing: 3

                                                    StyledText {
                                                        text: "Space"
                                                        font.pixelSize: 9
                                                        font.weight: Font.DemiBold
                                                        color: "#93c5fd"
                                                    }
                                                    StyledText {
                                                        text: "Preview"
                                                        font.pixelSize: 9
                                                        color: "#71717a"
                                                    }
                                                }
                                            }
                                        }

                                        // -------------------------------------------------------------
                                        // Footer Bar: Focus Indicator & Resolution Pill
                                        // -------------------------------------------------------------
                                        Rectangle {
                                            id: footerBar

                                            width: parent.width
                                            height: 30
                                            color: Qt.rgba(1.0, 1.0, 1.0, 0.02)

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12

                                                // Focus indicator pill
                                                Rectangle {
                                                    implicitHeight: 18
                                                    implicitWidth: focusRow.implicitWidth + 10
                                                    radius: 9
                                                    color: cardWrapper.modelData.activated ? Qt.rgba(0.19, 0.82, 0.35, 0.15) : Qt.rgba(1.0, 1.0, 1.0, 0.05)
                                                    border.width: 1
                                                    border.color: cardWrapper.modelData.activated ? Qt.rgba(0.19, 0.82, 0.35, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.06)

                                                    Row {
                                                        id: focusRow
                                                        anchors.centerIn: parent
                                                        spacing: 4

                                                        Rectangle {
                                                            width: 4
                                                            height: 4
                                                            radius: 2
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            color: cardWrapper.modelData.activated ? "#30D158" : "#71717a"
                                                        }

                                                        StyledText {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: cardWrapper.modelData.activated ? "Focused" : "Workspace"
                                                            font.pixelSize: 9
                                                            font.weight: Font.Medium
                                                            color: cardWrapper.modelData.activated ? "#30D158" : "#a1a1aa"
                                                        }
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                // Resolution chip
                                                StyledText {
                                                    text: `${cardWrapper.modelData.w || 0} × ${cardWrapper.modelData.h || 0}`
                                                    font.pixelSize: 9
                                                    font.weight: Font.Normal
                                                    color: "#52525b"
                                                }
                                            }
                                        }
                                    }

                                    // Main Click Target: Focuses the window
                                    MouseArea {
                                        id: cardArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.focusWindow(cardWrapper.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty Workspace Message
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: win.displayedWindows.length === 0

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "desktop_windows"
                        fontStyle: Tokens.font.icon.large
                        color: "#52525b"
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (root.searchQuery.length > 0) ? `No windows matching "${root.searchQuery}" on this workspace` : "No open windows on this workspace"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#71717a"
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Click any workspace above or press 1-9 to view other workspaces"
                        font.pixelSize: 11
                        color: "#52525b"
                    }
                }
            }

            // ---------------------------------------------------------------------
            // 4. BOTTOM HELPER SHORTCUT LEGEND
            // ---------------------------------------------------------------------
            RowLayout {
                id: bottomLegendBar

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 32
                spacing: 12

                Repeater {
                    model: [
                        { key: "1-9", label: "Open Workspace" },
                        { key: "← / →", label: "Navigate" },
                        { key: "Tab", label: "Cycle Windows" },
                        { key: "Space", label: "Quick Look" },
                        { key: "↵ Enter", label: "Focus" },
                        { key: "W", label: "Close" },
                        { key: "Esc", label: "Exit" }
                    ]

                    Rectangle {
                        required property var modelData

                        implicitHeight: 24
                        implicitWidth: shortcutRow.implicitWidth + 14
                        radius: 12
                        color: Qt.rgba(0.08, 0.09, 0.12, 0.65)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.06)

                        Row {
                            id: shortcutRow
                            anchors.centerIn: parent
                            spacing: 5

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.key
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: "#93c5fd"
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font.pixelSize: 10
                                color: "#71717a"
                            }
                        }
                    }
                }
            }
        }

        // =========================================================================
        // CONTEXTUAL PREVIEW UI SKELETON TEMPLATES
        // =========================================================================

        // Terminal / Code Editor Skeleton
        Component {
            id: terminalSkeleton

            Item {
                Row {
                    anchors.fill: parent
                    spacing: 8

                    // Gutter (Line numbers)
                    Column {
                        width: 16
                        spacing: 7
                        Repeater {
                            model: ["1", "2", "3", "4", "5", "6"]
                            StyledText {
                                required property string modelData
                                text: modelData
                                font.pixelSize: 9
                                color: "#3f3f46"
                            }
                        }
                    }

                    // Code / Console Canvas
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        spacing: 7

                        Row {
                            spacing: 5
                            StyledText {
                                text: "❯"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: "#30D158"
                            }
                            Rectangle {
                                width: 75
                                height: 7
                                radius: 2
                                color: Qt.rgba(0.4, 0.6, 1.0, 0.4)
                            }
                        }

                        Rectangle {
                            width: parent.width * 0.8
                            height: 6
                            radius: 2
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                        }
                        Rectangle {
                            width: parent.width * 0.6
                            height: 6
                            radius: 2
                            color: Qt.rgba(0.9, 0.7, 0.2, 0.25)
                        }
                        Rectangle {
                            width: parent.width * 0.7
                            height: 6
                            radius: 2
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                        }
                        Rectangle {
                            width: parent.width * 0.4
                            height: 6
                            radius: 2
                            color: Qt.rgba(0.3, 0.8, 0.5, 0.25)
                        }
                    }
                }
            }
        }

        // Web Browser Skeleton
        Component {
            id: browserSkeleton

            Item {
                Column {
                    anchors.fill: parent
                    spacing: 8

                    // URL address pill bar
                    Rectangle {
                        width: parent.width
                        height: 16
                        radius: 8
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.04)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: "#30D158"
                            }
                            Rectangle {
                                width: 90
                                height: 5
                                radius: 2
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
                            }
                        }
                    }

                    // Webpage Hero Block
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 6
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.04)
                    }

                    // Content 2-column cards
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 42
                            radius: 6
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                        }
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 42
                            radius: 6
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                        }
                    }
                }
            }
        }

        // Media Player Skeleton
        Component {
            id: mediaSkeleton

            Item {
                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    // Album Art
                    Rectangle {
                        width: 70
                        height: 70
                        radius: 8
                        color: Qt.rgba(0.40, 0.20, 0.55, 0.35)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "music_note"
                            fontStyle: Tokens.font.icon.large
                            color: "#c084fc"
                        }
                    }

                    // Track & Waveform skeleton
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 170
                        spacing: 8

                        Rectangle {
                            width: 120
                            height: 8
                            radius: 4
                            color: "#f4f4f5"
                        }
                        Rectangle {
                            width: 80
                            height: 6
                            radius: 3
                            color: "#71717a"
                        }

                        // Seek bar
                        Rectangle {
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                            Rectangle {
                                width: parent.width * 0.45
                                height: parent.height
                                radius: 2
                                color: "#60a5fa"
                            }
                        }
                    }
                }
            }
        }

        // Generic / Files Explorer Skeleton
        Component {
            id: genericSkeleton

            Item {
                Row {
                    anchors.fill: parent
                    spacing: 8

                    // Sidebar
                    Rectangle {
                        width: 50
                        height: parent.height
                        radius: 4
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.04)

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Repeater {
                                model: 4
                                Rectangle {
                                    width: 32
                                    height: 5
                                    radius: 2
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                }
                            }
                        }
                    }

                    // Content grid
                    Grid {
                        columns: 3
                        spacing: 8
                        Repeater {
                            model: 6
                            Rectangle {
                                width: 55
                                height: 38
                                radius: 6
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                                border.width: 1
                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.04)
                            }
                        }
                    }
                }
            }
        }

        // =========================================================================
        // QUICK LOOK OVERLAY (Spacebar Modal Viewport)
        // =========================================================================
        Rectangle {
            id: quickLookOverlay

            anchors.fill: parent
            color: Qt.rgba(0.02, 0.025, 0.035, 0.94)
            visible: root.quickLookWindow !== null
            opacity: visible ? 1.0 : 0.0
            z: 200

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Dismiss Quick Look on background click
            MouseArea {
                anchors.fill: parent
                onClicked: root.quickLookWindow = null
            }

            Rectangle {
                id: quickLookModal

                anchors.centerIn: parent
                width: Math.min(parent.width * 0.72, 860)
                height: Math.min(parent.height * 0.72, 560)
                radius: 16
                color: Qt.rgba(0.09, 0.10, 0.14, 0.95)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.18)

                GlassBevel { radius: 16 }

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    // Modal Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        IconImage {
                            implicitSize: 32
                            source: Quickshell.iconPath(root.quickLookWindow?.app_id || "", "application-x-executable")
                            asynchronous: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.quickLookWindow?.title || root.quickLookWindow?.app_id || "Window"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: "#f4f4f5"
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: `${root.quickLookWindow?.app_id || "Application"}  ·  ${root.quickLookWindow?.w || 0} × ${root.quickLookWindow?.h || 0} px`
                                font.pixelSize: 12
                                color: "#71717a"
                            }
                        }

                        // Close button
                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 16
                            color: qlCloseMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.12) : Qt.rgba(1.0, 1.0, 1.0, 0.06)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                fontStyle: Tokens.font.icon.medium
                                color: "#e4e4e7"
                            }

                            MouseArea {
                                id: qlCloseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.quickLookWindow = null
                            }
                        }
                    }

                    // Modal Large Preview Canvas
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        clip: true
                        color: "#08090c"
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                        CachingImage {
                            anchors.fill: parent
                            path: Wallpapers.current || Wallpapers.fallback
                            opacity: 0.35
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 14

                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: 64
                                source: Quickshell.iconPath(root.quickLookWindow?.app_id || "", "application-x-executable")
                                asynchronous: true
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.quickLookWindow?.title || ""
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: "#f4f4f5"
                            }
                        }
                    }

                    // Modal Footer Actions
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        StyledText {
                            text: "Press Space or Esc to return"
                            font.pixelSize: 11
                            color: "#52525b"
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 90
                            implicitHeight: 32
                            radius: 8
                            color: qlCloseBtnMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                            border.width: 1
                            border.color: qlCloseBtnMouse.containsMouse ? "#ef4444" : Qt.rgba(1.0, 1.0, 1.0, 0.12)

                            StyledText {
                                anchors.centerIn: parent
                                text: "Close"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: qlCloseBtnMouse.containsMouse ? "#ef4444" : "#e4e4e7"
                            }

                            MouseArea {
                                id: qlCloseBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.quickLookWindow) {
                                        CosmicWindows.close(root.quickLookWindow.id);
                                        root.quickLookWindow = null;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 120
                            implicitHeight: 32
                            radius: 8
                            color: qlFocusMouse.containsMouse ? "#3b82f6" : "#2563eb"

                            StyledText {
                                anchors.centerIn: parent
                                text: "Focus Window"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                            }

                            MouseArea {
                                id: qlFocusMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.focusWindow(root.quickLookWindow)
                            }
                        }
                    }
                }
            }
        }
    }
}
