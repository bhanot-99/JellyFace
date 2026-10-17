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
// State-of-the-art Workspace Switcher featuring Full Desktop Workspace Panels.
// Each virtual desktop is rendered as a miniature live desktop panel containing:
// 1. Proportional wallpaper background (Wallpapers.current)
// 2. Real window layouts positioned proportionally (x, y, w, h from wind helper)
// 3. Mini titlebars with app icons, titles, and hover dismiss (x)
// 4. Live search filtering across all workspaces (highlighting matches, dimming others)
// 5. Spring hover physics, workspace capsule switcher, and Quick Look modal (Spacebar).
Scope {
    id: root

    property string searchQuery: ""
    property var quickLookWindow: null

    // Helper: list windows on a specific workspace index
    function getWindowsForWorkspace(wsIndex: int): var {
        return CosmicWindows.windows.filter(w => {
            if (w.minimized)
                return false;
            if (w.workspace !== undefined && w.workspace >= 0)
                return w.workspace === wsIndex;
            // Fallback: if workspace is not assigned, match workspace_active with active workspace
            return w.workspace_active && wsIndex === CosmicWs.activeIndex;
        });
    }

    // Helper: test if window matches the search filter
    function isWindowMatch(w: var): bool {
        if (!searchQuery || searchQuery.trim().length === 0)
            return true;
        const q = searchQuery.trim().toLowerCase();
        const t = (w.title || "").toLowerCase();
        const a = (w.app_id || "").toLowerCase();
        return t.includes(q) || a.includes(q);
    }

    // Helper: test if workspace contains any matching windows
    function doesWorkspaceHaveMatch(wsIndex: int): bool {
        if (!searchQuery || searchQuery.trim().length === 0)
            return true;
        const wins = getWindowsForWorkspace(wsIndex);
        return wins.some(w => isWindowMatch(w));
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

        property int selectedWsIndex: Math.max(0, CosmicWs.activeIndex)
        property int selectedWinIndex: 0
        property string closingWindowId: ""

        readonly property real displayW: win.screen?.width ?? 1920
        readonly property real displayH: win.screen?.height ?? 1200
        readonly property real displayRatio: displayW / Math.max(1, displayH)

        // Workspace panel sizing: 460px width, height proportional to display aspect ratio
        readonly property int wsCardW: Math.min(480, Math.max(380, Math.round(win.width * 0.28)))
        readonly property int wsViewportH: Math.round(wsCardW / Math.max(1.2, displayRatio))
        readonly property int wsCardH: wsViewportH + 42

        function focusWindow(w: var): void {
            if (!w)
                return;
            root.quickLookWindow = null;
            root.searchQuery = "";
            CosmicWindows.activate(w.id);
            Overview.open = false;
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
        // PHASE 1: Atmospheric Obsidian Canvas & Top Radial Lighting Cone
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

        // Dismiss overview on backdrop click
        MouseArea {
            anchors.fill: parent
            z: 1
            onClicked: Overview.open = false
        }

        // =========================================================================
        // KEYBOARD-FIRST CONTROLLER
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
                } else {
                    const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                    if (wins.length > 0 && win.selectedWinIndex >= 0 && win.selectedWinIndex < wins.length)
                        win.focusWindow(wins[win.selectedWinIndex]);
                    else if (win.selectedWsIndex < CosmicWs.list.length) {
                        CosmicWs.activate(CosmicWs.list[win.selectedWsIndex].i);
                        Overview.open = false;
                    }
                }
            }

            Keys.onEnterPressed: {
                if (root.quickLookWindow) {
                    win.focusWindow(root.quickLookWindow);
                } else {
                    const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                    if (wins.length > 0 && win.selectedWinIndex >= 0 && win.selectedWinIndex < wins.length)
                        win.focusWindow(wins[win.selectedWinIndex]);
                    else if (win.selectedWsIndex < CosmicWs.list.length) {
                        CosmicWs.activate(CosmicWs.list[win.selectedWsIndex].i);
                        Overview.open = false;
                    }
                }
            }

            Keys.onSpacePressed: {
                if (root.quickLookWindow) {
                    root.quickLookWindow = null;
                } else {
                    const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                    if (wins.length > 0 && win.selectedWinIndex >= 0 && win.selectedWinIndex < wins.length)
                        root.quickLookWindow = wins[win.selectedWinIndex];
                }
            }

            Keys.onLeftPressed: {
                const totalWs = CosmicWs.list.length;
                if (totalWs > 0) {
                    win.selectedWsIndex = Math.max(0, win.selectedWsIndex - 1);
                    win.selectedWinIndex = 0;
                    CosmicWs.activate(CosmicWs.list[win.selectedWsIndex].i);
                }
            }

            Keys.onRightPressed: {
                const totalWs = CosmicWs.list.length;
                if (totalWs > 0) {
                    win.selectedWsIndex = Math.min(totalWs - 1, win.selectedWsIndex + 1);
                    win.selectedWinIndex = 0;
                    CosmicWs.activate(CosmicWs.list[win.selectedWsIndex].i);
                }
            }

            Keys.onTabPressed: {
                const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                if (wins.length > 0)
                    win.selectedWinIndex = (win.selectedWinIndex + 1) % wins.length;
            }

            Keys.onBacktabPressed: {
                const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                if (wins.length > 0)
                    win.selectedWinIndex = (win.selectedWinIndex - 1 + wins.length) % wins.length;
            }

            Keys.onUpPressed: {
                const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                if (wins.length > 0)
                    win.selectedWinIndex = Math.max(0, win.selectedWinIndex - 1);
            }

            Keys.onDownPressed: {
                const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                if (wins.length > 0)
                    win.selectedWinIndex = Math.min(wins.length - 1, win.selectedWinIndex + 1);
            }

            Keys.onPressed: event => {
                // Workspace jumps 1..9
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const wsIdx = event.key - Qt.Key_1;
                    if (wsIdx < CosmicWs.list.length) {
                        win.selectedWsIndex = wsIdx;
                        win.selectedWinIndex = 0;
                        CosmicWs.activate(CosmicWs.list[wsIdx].i);
                        event.accepted = true;
                    }
                } else if ((event.modifiers & Qt.ControlModifier && event.key === Qt.Key_K) || event.key === Qt.Key_Slash) {
                    searchInput.forceActiveFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_W && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ControlModifier)) {
                    const wins = root.getWindowsForWorkspace(win.selectedWsIndex);
                    if (wins.length > 0 && wins[win.selectedWinIndex]) {
                        CosmicWindows.close(wins[win.selectedWinIndex].id);
                        event.accepted = true;
                    }
                }
            }
        }

        // =========================================================================
        // MAIN CONTENT CONTAINER
        // =========================================================================
        Item {
            id: mainContent

            anchors.fill: parent
            anchors.margins: 28
            z: 10

            // ---------------------------------------------------------------------
            // TOP MISSION CONTROL BAR (Header & Capsule Controls)
            // ---------------------------------------------------------------------
            RowLayout {
                id: topBar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 52
                spacing: 16

                // Left Metadata Status Pill
                Rectangle {
                    implicitHeight: 40
                    implicitWidth: leftRow.implicitWidth + 24
                    radius: 20
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    GlassBevel { radius: 20 }

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
                            text: `·  ${CosmicWs.list.length} ${Tr.tr("Workspaces")}  ·  ${CosmicWindows.windows.length} ${Tr.tr("Windows")}`
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            color: "#71717a"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Center Floating Workspace Capsule
                Rectangle {
                    id: wsCapsule

                    implicitHeight: 40
                    implicitWidth: wsTabsRow.implicitWidth + 12
                    radius: 20
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    GlassBevel { radius: 20 }

                    // Animated Gliding Pill Indicator
                    Rectangle {
                        id: slidingPill

                        readonly property Item activeTab: {
                            const idx = CosmicWs.activeIndex;
                            if (idx >= 0 && idx < wsRepeater.count)
                                return wsRepeater.itemAt(idx);
                            return null;
                        }

                        x: activeTab ? (activeTab.x + 6) : 6
                        y: 4
                        width: activeTab ? activeTab.width : 54
                        height: 32
                        radius: 16
                        color: Qt.rgba(0.24, 0.40, 0.65, 0.45)
                        border.width: 1
                        border.color: Qt.rgba(0.40, 0.65, 1.0, 0.55)

                        Behavior on x {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                    }

                    Row {
                        id: wsTabsRow

                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            id: wsRepeater
                            model: CosmicWs.list.length > 0 ? CosmicWs.list : [{ i: 0, name: "1", active: true }]

                            Rectangle {
                                id: wsTab

                                required property var modelData
                                required property int index

                                readonly property bool isCurrentWs: CosmicWs.activeIndex === index || (modelData && modelData.active)
                                implicitWidth: Math.max(52, tabLabel.implicitWidth + 24)
                                implicitHeight: 32
                                radius: 16
                                color: "transparent"

                                StyledText {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: (wsTab.modelData?.name && wsTab.modelData.name.length > 0) ? `WS ${wsTab.modelData.name}` : `WS ${wsTab.index + 1}`
                                    font.pixelSize: 11
                                    font.weight: wsTab.isCurrentWs ? Font.DemiBold : Font.Normal
                                    color: wsTab.isCurrentWs ? "#f4f4f5" : "#71717a"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (wsTab.modelData && typeof wsTab.modelData.i === "number") {
                                            win.selectedWsIndex = wsTab.modelData.i;
                                            CosmicWs.activate(wsTab.modelData.i);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right Search Capsule (⌘K / Quick Filter)
                Rectangle {
                    id: searchCapsule

                    implicitHeight: 40
                    implicitWidth: searchInput.activeFocus || root.searchQuery.length > 0 ? 250 : 190
                    radius: 20
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: searchInput.activeFocus ? "#60a5fa" : Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    Behavior on implicitWidth {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    GlassBevel { radius: 20 }

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
                            implicitWidth: 32
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
            // CENTER: FULL WORKSPACE DESKTOP PANELS (COSMIC Style Viewer)
            // ---------------------------------------------------------------------
            Item {
                id: workspacesContainer

                anchors.top: topBar.bottom
                anchors.bottom: bottomLegendBar.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 20
                anchors.bottomMargin: 20

                Flickable {
                    id: wsFlickable

                    anchors.centerIn: parent
                    width: Math.min(parent.width, wsRow.implicitWidth)
                    height: wsRow.implicitHeight
                    contentWidth: wsRow.implicitWidth
                    contentHeight: wsRow.implicitHeight
                    clip: false
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: wsRow

                        spacing: 28
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            id: wsPanelsRepeater
                            model: CosmicWs.list.length > 0 ? CosmicWs.list : [{ i: 0, name: "1", active: true }]

                            // FULL WORKSPACE DESKTOP PANEL
                            Item {
                                id: wsCard

                                required property var modelData
                                required property int index

                                readonly property bool isSelected: win.selectedWsIndex === wsCard.index
                                readonly property bool isActive: (CosmicWs.activeIndex === wsCard.index) || (wsCard.modelData && wsCard.modelData.active)
                                readonly property var wsWindows: root.getWindowsForWorkspace(wsCard.modelData.i)
                                readonly property bool hasMatch: root.doesWorkspaceHaveMatch(wsCard.modelData.i)

                                width: win.wsCardW
                                height: win.wsCardH
                                opacity: hasMatch ? 1.0 : 0.28

                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                // Spring-like hover physics on entire workspace panel
                                transform: [
                                    Translate {
                                        id: wsTrans
                                        y: wsCardMouse.containsMouse ? -6 : (wsCard.isSelected ? -3 : 0)
                                        Behavior on y {
                                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                        }
                                    },
                                    Scale {
                                        id: wsScale
                                        origin.x: wsCard.width / 2
                                        origin.y: wsCard.height / 2
                                        xScale: wsCardMouse.containsMouse ? 1.018 : (wsCard.isSelected ? 1.01 : 1.0)
                                        yScale: xScale
                                        Behavior on xScale {
                                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                        }
                                    }
                                ]

                                Column {
                                    anchors.fill: parent
                                    spacing: 8

                                    // Workspace Top Header
                                    RowLayout {
                                        width: parent.width
                                        height: 28

                                        // Left: Workspace badge
                                        RowLayout {
                                            spacing: 6

                                            Rectangle {
                                                implicitWidth: wsTitleText.implicitWidth + 14
                                                implicitHeight: 22
                                                radius: 6
                                                color: wsCard.isActive ? Qt.rgba(0.24, 0.40, 0.65, 0.45) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                                border.width: 1
                                                border.color: wsCard.isActive ? "#60a5fa" : Qt.rgba(1.0, 1.0, 1.0, 0.10)

                                                StyledText {
                                                    id: wsTitleText
                                                    anchors.centerIn: parent
                                                    text: (wsCard.modelData.name && wsCard.modelData.name.length > 0) ? `Workspace ${wsCard.modelData.name}` : `Workspace ${wsCard.index + 1}`
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: wsCard.isActive ? "#93c5fd" : "#e4e4e7"
                                                }
                                            }

                                            // Active pill indicator
                                            Rectangle {
                                                implicitWidth: 54
                                                implicitHeight: 20
                                                radius: 10
                                                visible: wsCard.isActive
                                                color: Qt.rgba(0.19, 0.82, 0.35, 0.15)
                                                border.width: 1
                                                border.color: Qt.rgba(0.19, 0.82, 0.35, 0.35)

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Rectangle {
                                                        width: 5
                                                        height: 5
                                                        radius: 2.5
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        color: "#30D158"
                                                    }

                                                    StyledText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Active"
                                                        font.pixelSize: 9
                                                        font.weight: Font.Medium
                                                        color: "#30D158"
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        // Right: Windows Count Badge
                                        Rectangle {
                                            implicitWidth: countText.implicitWidth + 12
                                            implicitHeight: 20
                                            radius: 10
                                            color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.06)

                                            StyledText {
                                                id: countText
                                                anchors.centerIn: parent
                                                text: `${wsCard.wsWindows.length} ${wsCard.wsWindows.length === 1 ? "win" : "wins"}`
                                                font.pixelSize: 10
                                                font.weight: Font.Normal
                                                color: "#a1a1aa"
                                            }
                                        }
                                    }

                                    // Real Desktop Miniature Viewport
                                    Rectangle {
                                        id: desktopViewport

                                        width: wsCard.width
                                        height: win.wsViewportH
                                        radius: 12
                                        clip: true
                                        color: "#0c0d12"
                                        border.width: wsCard.isActive ? 2 : (wsCard.isSelected ? 1.5 : 1)
                                        border.color: wsCard.isActive ? "#60a5fa" : (wsCard.isSelected ? Qt.rgba(1.0, 1.0, 1.0, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.10))

                                        Behavior on border.color {
                                            ColorAnimation { duration: 200 }
                                        }

                                        // Layer 1: Real Desktop Wallpaper Background
                                        CachingImage {
                                            anchors.fill: parent
                                            path: Wallpapers.current || Wallpapers.fallback
                                            opacity: 0.85
                                        }

                                        // Layer 2: Frosted dark tint for strong window contrast
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(0.06, 0.07, 0.09, 0.45)
                                        }

                                        // Layer 3: Glass Bevel highlight around perimeter
                                        GlassBevel { radius: 12 }

                                        // Layer 4: Real Windows Proportional Layout Layer
                                        Item {
                                            id: windowsLayoutLayer
                                            anchors.fill: parent

                                            readonly property real scaleX: desktopViewport.width / win.displayW
                                            readonly property real scaleY: desktopViewport.height / win.displayH

                                            // Render every window that belongs to this workspace
                                            Repeater {
                                                model: wsCard.wsWindows

                                                Item {
                                                    id: miniWinItem

                                                    required property var modelData
                                                    required property int index

                                                    readonly property bool isClosing: win.closingWindowId === miniWinItem.modelData.id.toString()
                                                    readonly property bool isMatch: root.isWindowMatch(miniWinItem.modelData)
                                                    readonly property bool isSelectedWin: wsCard.isSelected && win.selectedWinIndex === miniWinItem.index
                                                    readonly property bool isWinActive: miniWinItem.modelData.activated

                                                    // Calculate proportional coordinates based on actual window geometry
                                                    readonly property int targetW: (miniWinItem.modelData.w > 0 && miniWinItem.modelData.h > 0)
                                                        ? Math.max(56, Math.min(desktopViewport.width, Math.round(miniWinItem.modelData.w * windowsLayoutLayer.scaleX)))
                                                        : Math.round(desktopViewport.width * 0.7)

                                                    readonly property int targetH: (miniWinItem.modelData.w > 0 && miniWinItem.modelData.h > 0)
                                                        ? Math.max(40, Math.min(desktopViewport.height, Math.round(miniWinItem.modelData.h * windowsLayoutLayer.scaleY)))
                                                        : Math.round(desktopViewport.height * 0.7)

                                                    readonly property int targetX: (miniWinItem.modelData.w > 0 && miniWinItem.modelData.h > 0)
                                                        ? Math.round(miniWinItem.modelData.x * windowsLayoutLayer.scaleX)
                                                        : Math.round((desktopViewport.width - targetW) / 2)

                                                    readonly property int targetY: (miniWinItem.modelData.w > 0 && miniWinItem.modelData.h > 0)
                                                        ? Math.round(miniWinItem.modelData.y * windowsLayoutLayer.scaleY)
                                                        : Math.round((desktopViewport.height - targetH) / 2)

                                                    x: Math.max(0, Math.min(desktopViewport.width - width, targetX))
                                                    y: Math.max(0, Math.min(desktopViewport.height - height, targetY))
                                                    width: targetW
                                                    height: targetH

                                                    opacity: isClosing ? 0.0 : (isMatch ? 1.0 : 0.22)
                                                    scale: isClosing ? 0.88 : (miniWinMouse.containsMouse ? 1.04 : 1.0)
                                                    z: miniWinMouse.containsMouse ? 100 : (isWinActive ? 50 : 10)

                                                    Behavior on opacity {
                                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                                    }
                                                    Behavior on scale {
                                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                                    }

                                                    // Mini Window Container Card
                                                    Rectangle {
                                                        id: miniWinRect

                                                        anchors.fill: parent
                                                        radius: 6
                                                        clip: true
                                                        color: miniWinItem.isWinActive ? Qt.rgba(0.14, 0.17, 0.24, 0.94) : Qt.rgba(0.09, 0.10, 0.14, 0.88)
                                                        border.width: miniWinItem.isSelectedWin ? 2 : (miniWinItem.isWinActive ? 1.5 : 1)
                                                        border.color: miniWinItem.isSelectedWin ? "#60a5fa" : (miniWinItem.isWinActive ? Qt.rgba(0.40, 0.65, 1.0, 0.7) : (miniWinMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.14)))

                                                        // Subtle Drop Shadow
                                                        Rectangle {
                                                            anchors.fill: parent
                                                            anchors.margins: -1
                                                            radius: 6
                                                            z: -1
                                                            color: "transparent"
                                                            border.width: 1
                                                            border.color: Qt.rgba(0, 0, 0, 0.40)
                                                        }

                                                        Column {
                                                            anchors.fill: parent

                                                            // Mini Window Titlebar
                                                            Rectangle {
                                                                width: parent.width
                                                                height: Math.min(18, parent.height * 0.35)
                                                                color: Qt.rgba(1.0, 1.0, 1.0, 0.05)

                                                                RowLayout {
                                                                    anchors.fill: parent
                                                                    anchors.leftMargin: 4
                                                                    anchors.rightMargin: 4
                                                                    spacing: 4

                                                                    IconImage {
                                                                        implicitSize: 11
                                                                        source: Quickshell.iconPath(miniWinItem.modelData.app_id || "", "application-x-executable")
                                                                        asynchronous: true
                                                                        Layout.alignment: Qt.AlignVCenter
                                                                    }

                                                                    StyledText {
                                                                        Layout.fillWidth: true
                                                                        text: miniWinItem.modelData.title || miniWinItem.modelData.app_id || "Window"
                                                                        elide: Text.ElideRight
                                                                        font.pixelSize: 8
                                                                        font.weight: Font.Medium
                                                                        color: miniWinItem.isWinActive ? "#f4f4f5" : "#d4d4d8"
                                                                    }

                                                                    // Close button on hover
                                                                    MaterialIcon {
                                                                        text: "close"
                                                                        fontStyle: Tokens.font.icon.extraSmall
                                                                        color: miniCloseMouse.containsMouse ? "#ef4444" : "#71717a"
                                                                        opacity: miniWinMouse.containsMouse ? 1.0 : 0.0
                                                                        Layout.alignment: Qt.AlignVCenter

                                                                        Behavior on opacity {
                                                                            NumberAnimation { duration: 150 }
                                                                        }

                                                                        MouseArea {
                                                                            id: miniCloseMouse
                                                                            anchors.fill: parent
                                                                            anchors.margins: -3
                                                                            hoverEnabled: true
                                                                            cursorShape: Qt.PointingHandCursor
                                                                            onClicked: {
                                                                                win.closingWindowId = miniWinItem.modelData.id.toString();
                                                                                closeTimer.start();
                                                                            }

                                                                            Timer {
                                                                                id: closeTimer
                                                                                interval: 160
                                                                                onTriggered: {
                                                                                    CosmicWindows.close(miniWinItem.modelData.id);
                                                                                    win.closingWindowId = "";
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            // Mini Window Body Canvas (Representative Interior)
                                                            Item {
                                                                width: parent.width
                                                                height: parent.height - Math.min(18, parent.height * 0.35)

                                                                // Subtle App-Type UI Lines
                                                                Column {
                                                                    anchors.centerIn: parent
                                                                    width: Math.max(10, parent.width - 12)
                                                                    spacing: 3
                                                                    opacity: 0.60

                                                                    Rectangle {
                                                                        width: parent.width * 0.75
                                                                        height: 2
                                                                        radius: 1
                                                                        color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                                                                    }
                                                                    Rectangle {
                                                                        width: parent.width * 0.90
                                                                        height: 2
                                                                        radius: 1
                                                                        color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                                                    }
                                                                    Rectangle {
                                                                        width: parent.width * 0.50
                                                                        height: 2
                                                                        radius: 1
                                                                        color: Qt.rgba(0.40, 0.65, 1.0, 0.18)
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        // Click or hover on this specific window
                                                        MouseArea {
                                                            id: miniWinMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                win.focusWindow(miniWinItem.modelData);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Empty Workspace Placeholder
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            visible: wsCard.wsWindows.length === 0
                                            opacity: 0.40

                                            MaterialIcon {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "desktop_windows"
                                                fontStyle: Tokens.font.icon.large
                                                color: "#71717a"
                                            }

                                            StyledText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "Empty Workspace"
                                                font.pixelSize: 11
                                                color: "#71717a"
                                            }
                                        }

                                        // Click on empty workspace area to activate workspace
                                        MouseArea {
                                            id: wsCardMouse
                                            anchors.fill: parent
                                            z: 0
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.selectedWsIndex = wsCard.modelData.i;
                                                CosmicWs.activate(wsCard.modelData.i);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------------------
            // BOTTOM HELPER LEGEND BAR
            // ---------------------------------------------------------------------
            RowLayout {
                id: bottomLegendBar

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 36
                spacing: 12

                Repeater {
                    model: [
                        { key: "1-9", label: "Jump Workspace" },
                        { key: "← / →", label: "Select Workspace" },
                        { key: "Tab", label: "Cycle Windows" },
                        { key: "Space", label: "Quick Look" },
                        { key: "↵ Enter", label: "Focus" },
                        { key: "W", label: "Close" },
                        { key: "Esc", label: "Exit" }
                    ]

                    Rectangle {
                        required property var modelData

                        implicitHeight: 26
                        implicitWidth: shortcutRow.implicitWidth + 14
                        radius: 13
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
                                font.weight: Font.Normal
                                color: "#71717a"
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
                    // Prevent dismissal when clicking inside modal
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
