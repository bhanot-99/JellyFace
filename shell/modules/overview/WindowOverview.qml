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
import qs.services
import qs.utils

// Mission Control / Exposé Window Overview:
// State-of-the-art Workspace Switcher & Live Window Viewport Hub.
// Features atmospheric obsidian depth, radial lighting cones, 16:10 contextual viewports
// with realistic UI skeletons, floating workspace capsule with gliding pill indicator,
// live search filter, spring hover physics, and Quick Look modal (Spacebar).
Scope {
    id: root

    property string searchQuery: ""
    property var quickLookWindow: null

    // Filter windows on the current active workspace that are not minimized
    readonly property var activeWindows: CosmicWindows.windows.filter(w => w.workspace_active && !w.minimized)

    // Filter windows by search query (app_id or title)
    readonly property var filteredWindows: {
        const q = searchQuery.trim().toLowerCase();
        if (q.length === 0)
            return activeWindows;
        return activeWindows.filter(w => {
            const t = (w.title || "").toLowerCase();
            const a = (w.app_id || "").toLowerCase();
            return t.includes(q) || a.includes(q);
        });
    }

    // Categorize application type for realistic preview UI skeleton
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

        readonly property var winList: root.filteredWindows
        property int selectedIndex: 0
        readonly property int gridCols: Math.max(1, Math.min(4, Math.ceil(Math.sqrt(winList.length))))

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
                win.selectedIndex = 0;
                root.searchQuery = "";
                root.quickLookWindow = null;
                keyController.forceActiveFocus();
            } else {
                root.quickLookWindow = null;
                root.searchQuery = "";
            }
        }

        // =========================================================================
        // PHASE 1: Atmospheric Canvas & Material Foundation
        // =========================================================================

        // 1. Deep Obsidian Base (#08080a with 90% opacity)
        Rectangle {
            id: baseObsidian
            anchors.fill: parent
            color: Qt.rgba(0.031, 0.031, 0.039, 0.90)
        }

        // 2. Subtle Atmospheric Light Cones (Natural light hitting frosted sheet)
        Shape {
            id: atmosphericLight
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillGradient: RadialGradient {
                    centerX: win.width * 0.5
                    centerY: 0
                    centerRadius: win.width * 0.55
                    focalX: centerX
                    focalY: 0

                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(0.38, 0.48, 0.70, 0.16)
                    }
                    GradientStop {
                        position: 0.45
                        color: Qt.rgba(0.20, 0.25, 0.38, 0.05)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
                strokeColor: "transparent"

                startX: 0
                startY: 0
                PathLine { x: win.width; y: 0 }
                PathLine { x: win.width; y: win.height }
                PathLine { x: 0; y: win.height }
                PathLine { x: 0; y: 0 }
            }
        }

        // Click outside cards to dismiss overview
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.quickLookWindow)
                    root.quickLookWindow = null;
                else
                    Overview.open = false;
            }
        }

        // Keyboard Controller & Shortcuts
        Item {
            id: keyController

            anchors.fill: parent
            focus: win.visible

            Keys.onEscapePressed: {
                if (root.quickLookWindow)
                    root.quickLookWindow = null;
                else if (root.searchQuery.length > 0)
                    root.searchQuery = "";
                else
                    Overview.open = false;
            }

            Keys.onReturnPressed: {
                if (root.quickLookWindow)
                    win.focusWindow(root.quickLookWindow);
                else if (win.winList.length > 0)
                    win.focusWindow(win.winList[win.selectedIndex]);
            }

            Keys.onEnterPressed: {
                if (root.quickLookWindow)
                    win.focusWindow(root.quickLookWindow);
                else if (win.winList.length > 0)
                    win.focusWindow(win.winList[win.selectedIndex]);
            }

            Keys.onSpacePressed: {
                if (win.winList.length > 0) {
                    if (root.quickLookWindow)
                        root.quickLookWindow = null;
                    else
                        root.quickLookWindow = win.winList[win.selectedIndex];
                }
            }

            Keys.onTabPressed: {
                if (win.winList.length > 0)
                    win.selectedIndex = (win.selectedIndex + 1) % win.winList.length;
            }

            Keys.onBacktabPressed: {
                if (win.winList.length > 0)
                    win.selectedIndex = (win.selectedIndex - 1 + win.winList.length) % win.winList.length;
            }

            Keys.onLeftPressed: {
                if (win.winList.length > 0)
                    win.selectedIndex = Math.max(0, win.selectedIndex - 1);
            }

            Keys.onRightPressed: {
                if (win.winList.length > 0)
                    win.selectedIndex = Math.min(win.winList.length - 1, win.selectedIndex + 1);
            }

            Keys.onUpPressed: {
                if (win.winList.length > 0)
                    win.selectedIndex = Math.max(0, win.selectedIndex - win.gridCols);
            }

            Keys.onDownPressed: {
                if (win.winList.length > 0)
                    win.selectedIndex = Math.min(win.winList.length - 1, win.selectedIndex + win.gridCols);
            }

            Keys.onPressed: event => {
                // Workspace jumps 1..9
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const wsIdx = event.key - Qt.Key_1;
                    if (wsIdx < CosmicWs.list.length) {
                        CosmicWs.activate(CosmicWs.list[wsIdx].i);
                        event.accepted = true;
                    }
                } else if ((event.modifiers & Qt.ControlModifier && event.key === Qt.Key_K) || event.key === Qt.Key_Slash) {
                    searchInput.forceActiveFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_W && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ControlModifier)) {
                    if (win.winList.length > 0 && win.winList[win.selectedIndex]) {
                        CosmicWindows.close(win.winList[win.selectedIndex].id);
                        event.accepted = true;
                    }
                }
            }
        }

        // =========================================================================
        // PHASE 3: Spatial Layout & Top Mission Control Control Hub
        // =========================================================================
        Item {
            id: mainContent

            anchors.fill: parent
            anchors.margins: 36

            // Top Mission Control Header Bar
            Item {
                id: topBar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44

                // Left Anchor: Quiet Overview Metadata Pill
                Rectangle {
                    id: overviewStatusPill

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 38
                    width: statusRow.width + 24
                    radius: 19
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 8

                        // Glowing emerald status dot
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            color: "#30D158"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                radius: 6.5
                                color: Qt.rgba(0.19, 0.82, 0.35, 0.30)
                            }
                        }

                        StyledText {
                            text: "Overview"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: "#f4f4f5"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: `·  ${root.filteredWindows.length} ${root.filteredWindows.length === 1 ? "window" : "windows"}`
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            color: "#71717a"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Center Anchor: Floating Workspace Capsule Pill Bar
                Rectangle {
                    id: workspaceCapsule

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    height: 38
                    width: wsRow.width + 12
                    radius: 19
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    // Sliding Background Indicator
                    Rectangle {
                        id: slidingIndicator

                        height: 30
                        radius: 15
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.20)
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property Item activeTab: {
                            const idx = CosmicWs.activeIndex;
                            if (idx >= 0 && idx < wsRepeater.count)
                                return wsRepeater.itemAt(idx);
                            return null;
                        }

                        x: activeTab ? (wsRow.x + activeTab.x) : 6
                        width: activeTab ? activeTab.width : 54

                        Behavior on x {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                    }

                    Row {
                        id: wsRow

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

                                width: Math.max(64, tabContent.width + 20)
                                height: 30
                                radius: 15
                                color: "transparent"

                                Row {
                                    id: tabContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    StyledText {
                                        text: (wsTab.modelData?.name && wsTab.modelData.name.length > 0) ? `WS ${wsTab.modelData.name}` : `WS ${wsTab.index + 1}`
                                        font.pixelSize: 12
                                        font.weight: wsTab.isCurrentWs ? Font.DemiBold : Font.Normal
                                        color: wsTab.isCurrentWs ? "#f4f4f5" : "#71717a"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (wsTab.modelData && typeof wsTab.modelData.i === "number")
                                            CosmicWs.activate(wsTab.modelData.i);
                                    }
                                }
                            }
                        }
                    }
                }

                // Right Anchor: Search / Quick Filter Bar
                Rectangle {
                    id: searchBar

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 38
                    width: searchFocusArea.hovered || searchInput.activeFocus || searchInput.text.length > 0 ? 240 : 180
                    radius: 19
                    color: searchInput.activeFocus ? Qt.rgba(0.12, 0.14, 0.20, 0.90) : Qt.rgba(0.08, 0.09, 0.12, 0.75)
                    border.width: 1
                    border.color: searchInput.activeFocus ? Qt.rgba(0.38, 0.65, 0.98, 0.60) : Qt.rgba(1.0, 1.0, 1.0, 0.08)

                    Behavior on width {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    HoverHandler {
                        id: searchFocusArea
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialIcon {
                            text: "search"
                            color: searchInput.activeFocus ? "#60a5fa" : "#71717a"
                            font.pointSize: 15
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
                                if (win.winList.length > 0)
                                    win.focusWindow(win.winList[win.selectedIndex]);
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

                        // Clear search or shortcut pill
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
                                font.pointSize: 13
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

            // =========================================================================
            // PHASE 2 & 4: Centered Dynamic Responsive Grid & 16:10 Viewport Cards
            // =========================================================================

            // Empty State
            Item {
                anchors.centerIn: parent
                visible: win.winList.length === 0
                width: 320
                height: 120

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchQuery.length > 0 ? "search_off" : "desktop_windows"
                        color: "#52525b"
                        font.pointSize: 36
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchQuery.length > 0 ? `No windows match "${root.searchQuery}"` : "No active windows on this workspace"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#d4d4d8"
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Press [1-9] to switch workspaces or [Esc] to exit"
                        font.pixelSize: 12
                        color: "#71717a"
                    }
                }
            }

            // Cards Grid Viewport
            Flickable {
                id: gridScroll

                anchors.top: topBar.bottom
                anchors.topMargin: 36
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                contentWidth: width
                contentHeight: gridContainer.height + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    id: gridContainer

                    width: Math.min(gridScroll.width, Math.max(360, cardGrid.implicitWidth))
                    height: cardGrid.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter

                    Grid {
                        id: cardGrid

                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: win.gridCols
                        spacing: 24

                        Repeater {
                            model: win.winList

                            // 16:10 Window Viewport Card
                            Item {
                                id: cardWrapper

                                required property var modelData
                                required property int index

                                width: 340
                                height: 226

                                readonly property bool isSelected: win.selectedIndex === index
                                readonly property string category: root.getAppCategory(modelData.app_id, modelData.title)

                                // Card Body with Spring-like Hover Elevation & Transform
                                Rectangle {
                                    id: card

                                    anchors.fill: parent
                                    radius: 16
                                    color: cardHover.hovered || cardWrapper.isSelected ? Qt.rgba(0.12, 0.13, 0.18, 0.88) : Qt.rgba(0.07, 0.08, 0.11, 0.75)
                                    border.width: cardWrapper.isSelected ? 2 : 1
                                    border.color: cardWrapper.isSelected ? Qt.rgba(0.40, 0.65, 0.98, 0.70) : (cardHover.hovered ? Qt.rgba(1.0, 1.0, 1.0, 0.22) : Qt.rgba(1.0, 1.0, 1.0, 0.08))
                                    clip: true

                                    transform: [
                                        Translate {
                                            y: cardHover.hovered ? -5 : 0
                                            Behavior on y {
                                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                            }
                                        },
                                        Scale {
                                            origin.x: card.width / 2
                                            origin.y: card.height / 2
                                            xScale: cardHover.hovered ? 1.018 : 1.0
                                            yScale: cardHover.hovered ? 1.018 : 1.0
                                            Behavior on xScale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                            Behavior on yScale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                        }
                                    ]

                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation { duration: 200 }
                                    }

                                    // Top Inset Specular Sheen (GlassBevel)
                                    GlassBevel {
                                        radius: card.radius
                                        bevelOpacity: cardHover.hovered || cardWrapper.isSelected ? 0.9 : 0.4
                                    }

                                    // Interior Card Layout: Header Bar -> Preview Viewport -> Footer Bar
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        // 1. Dedicated Window Header Bar
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            spacing: 10

                                            // App Icon Badge
                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 6
                                                color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
                                                border.width: 1
                                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                                                IconImage {
                                                    anchors.centerIn: parent
                                                    implicitSize: 16
                                                    source: Quickshell.iconPath(cardWrapper.modelData.app_id || "", "application-x-executable")
                                                    asynchronous: true
                                                }
                                            }

                                            // Window Title & App ID Subtitle
                                            Column {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                StyledText {
                                                    width: parent.width
                                                    text: cardWrapper.modelData.title || cardWrapper.modelData.app_id || "Window"
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: "#f4f4f5"
                                                    elide: Text.ElideMiddle
                                                }

                                                StyledText {
                                                    width: parent.width
                                                    text: cardWrapper.modelData.app_id || "Application"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Normal
                                                    color: "#71717a"
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // Hover-reveal Dismiss (×) Button
                                            Rectangle {
                                                id: dismissBtn

                                                width: 22
                                                height: 22
                                                radius: 11
                                                color: dismissHover.hovered ? Qt.rgba(0.95, 0.25, 0.25, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                                                opacity: cardHover.hovered || cardWrapper.isSelected ? 1.0 : 0.0

                                                Behavior on opacity {
                                                    NumberAnimation { duration: 180 }
                                                }

                                                MaterialIcon {
                                                    anchors.centerIn: parent
                                                    text: "close"
                                                    font.pointSize: 12
                                                    color: dismissHover.hovered ? "#ff6b6b" : "#d4d4d8"
                                                }

                                                HoverHandler {
                                                    id: dismissHover
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: CosmicWindows.close(cardWrapper.modelData.id)
                                                }
                                            }
                                        }

                                        // 2. High-Fidelity 16:10 Preview Viewport
                                        Rectangle {
                                            id: previewViewport

                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 10
                                            color: "#0a0b0e"
                                            border.width: 1
                                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
                                            clip: true

                                            // Contextual Skeleton Viewports based on App Category
                                            Loader {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                sourceComponent: {
                                                    switch (cardWrapper.category) {
                                                    case "terminal": return terminalSkeleton;
                                                    case "browser": return browserSkeleton;
                                                    case "media": return mediaSkeleton;
                                                    default: return genericSkeleton;
                                                    }
                                                }
                                            }

                                            // Soft Radial Vignette Gradient Overlay
                                            Rectangle {
                                                anchors.fill: parent
                                                color: "transparent"
                                                border.width: 1
                                                border.color: Qt.rgba(0.0, 0.0, 0.0, 0.30)
                                                radius: previewViewport.radius
                                            }

                                            // Click to expand / focus
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: win.focusWindow(cardWrapper.modelData)
                                            }
                                        }

                                        // 3. Subtle Footer Pill Bar
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22

                                            // Focus / Active Tag
                                            Rectangle {
                                                height: 18
                                                width: activeTagRow.width + 12
                                                radius: 9
                                                color: cardWrapper.modelData.activated ? Qt.rgba(0.19, 0.82, 0.35, 0.15) : Qt.rgba(1.0, 1.0, 1.0, 0.05)
                                                border.width: 1
                                                border.color: cardWrapper.modelData.activated ? Qt.rgba(0.19, 0.82, 0.35, 0.35) : Qt.rgba(1.0, 1.0, 1.0, 0.06)

                                                Row {
                                                    id: activeTagRow
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Rectangle {
                                                        width: 5
                                                        height: 5
                                                        radius: 2.5
                                                        color: cardWrapper.modelData.activated ? "#30D158" : "#71717a"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    StyledText {
                                                        text: cardWrapper.modelData.activated ? "Focused" : "Workspace"
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: cardWrapper.modelData.activated ? "#30D158" : "#a1a1aa"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Tabular Monospace Resolution / Geometry
                                            StyledText {
                                                text: `${cardWrapper.modelData.w || 0} × ${cardWrapper.modelData.h || 0}`
                                                font.pixelSize: 10
                                                font.weight: Font.Normal
                                                color: "#71717a"
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: cardHover
                                        onHoveredChanged: {
                                            if (cardHover.hovered)
                                                win.selectedIndex = cardWrapper.index;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =========================================================================
        // UI Skeleton Templates for Contextual Card Interiors
        // =========================================================================

        // 1. Terminal / Editor Skeleton (Gutters, realistic code lines, blinking cursor)
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

                        // Prompt line
                        Row {
                            spacing: 5
                            StyledText {
                                text: "❯"
                                font.pixelSize: 9
                                color: "#30D158"
                            }
                            Rectangle {
                                width: 70
                                height: 7
                                radius: 2
                                color: Qt.rgba(0.19, 0.82, 0.35, 0.40)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Code syntax lines
                        Row {
                            spacing: 4
                            Rectangle { width: 34; height: 6; radius: 2; color: Qt.rgba(0.75, 0.52, 0.98, 0.45) }
                            Rectangle { width: 55; height: 6; radius: 2; color: Qt.rgba(0.38, 0.65, 0.98, 0.40) }
                            Rectangle { width: 40; height: 6; radius: 2; color: Qt.rgba(0.29, 0.87, 0.50, 0.40) }
                        }

                        Row {
                            spacing: 4
                            Rectangle { width: 18; height: 6; radius: 2; color: "transparent" }
                            Rectangle { width: 48; height: 6; radius: 2; color: Qt.rgba(0.96, 0.62, 0.04, 0.40) }
                            Rectangle { width: 65; height: 6; radius: 2; color: Qt.rgba(0.85, 0.85, 0.85, 0.25) }
                        }

                        Row {
                            spacing: 4
                            Rectangle { width: 18; height: 6; radius: 2; color: "transparent" }
                            Rectangle { width: 75; height: 6; radius: 2; color: Qt.rgba(0.38, 0.65, 0.98, 0.35) }
                            Rectangle { width: 4; height: 9; color: "#f4f4f5"; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Row {
                            spacing: 4
                            Rectangle { width: 25; height: 6; radius: 2; color: Qt.rgba(0.75, 0.52, 0.98, 0.40) }
                        }
                    }
                }
            }
        }

        // 2. Browser Skeleton (Mini tab/URL strip, hero block, content cards)
        Component {
            id: browserSkeleton

            Column {
                anchors.fill: parent
                spacing: 8

                // Browser mini address strip
                Row {
                    width: parent.width
                    spacing: 6

                    Row {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle { width: 5; height: 5; radius: 2.5; color: "#ef4444" }
                        Rectangle { width: 5; height: 5; radius: 2.5; color: "#eab308" }
                        Rectangle { width: 5; height: 5; radius: 2.5; color: "#22c55e" }
                    }

                    Rectangle {
                        width: parent.width - 32
                        height: 12
                        radius: 6
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 50
                            height: 4
                            radius: 2
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.25)
                        }
                    }
                }

                // Content Hero Box
                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 6
                    color: Qt.rgba(0.20, 0.25, 0.35, 0.30)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                }

                // 2-column cards
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 38
                        radius: 6
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                    }
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 38
                        radius: 6
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                    }
                }
            }
        }

        // 3. Media Player Skeleton (Dark stage, center album vinyl glow, progress bar)
        Component {
            id: mediaSkeleton

            Item {
                anchors.fill: parent

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: Qt.rgba(0.98, 0.35, 0.42, 0.20)
                        border.width: 1
                        border.color: Qt.rgba(0.98, 0.35, 0.42, 0.40)

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "play_arrow"
                            color: "#FA586A"
                            font.pointSize: 22
                        }
                    }

                    // Progress track
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 160
                        height: 4
                        radius: 2
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.12)

                        Rectangle {
                            width: 65
                            height: parent.height
                            radius: 2
                            color: "#FA586A"
                        }
                    }
                }
            }
        }

        // 4. Generic / Files App Skeleton
        Component {
            id: genericSkeleton

            Row {
                anchors.fill: parent
                spacing: 10

                // Left sidebar
                Column {
                    width: 45
                    spacing: 6
                    Rectangle { width: 35; height: 6; radius: 2; color: Qt.rgba(1.0, 1.0, 1.0, 0.18) }
                    Rectangle { width: 40; height: 6; radius: 2; color: Qt.rgba(1.0, 1.0, 1.0, 0.10) }
                    Rectangle { width: 30; height: 6; radius: 2; color: Qt.rgba(1.0, 1.0, 1.0, 0.10) }
                    Rectangle { width: 38; height: 6; radius: 2; color: Qt.rgba(1.0, 1.0, 1.0, 0.10) }
                }

                // Grid content
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

            // Quick Look Viewport Modal Card
            Rectangle {
                id: qlModal

                anchors.centerIn: parent
                width: Math.min(1080, win.width * 0.72)
                height: Math.min(680, win.height * 0.72)
                radius: 20
                color: Qt.rgba(0.08, 0.09, 0.13, 0.96)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                clip: true

                scale: quickLookOverlay.visible ? 1.0 : 0.88
                Behavior on scale {
                    NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
                }

                GlassBevel {
                    radius: qlModal.radius
                    bevelOpacity: 0.8
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // Modal Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        spacing: 12

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 22
                                source: Quickshell.iconPath(root.quickLookWindow?.app_id || "", "application-x-executable")
                                asynchronous: true
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            StyledText {
                                text: root.quickLookWindow?.title || root.quickLookWindow?.app_id || "Quick Look"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: "#f4f4f5"
                                elide: Text.ElideMiddle
                            }
                            StyledText {
                                text: root.quickLookWindow?.app_id || ""
                                font.pixelSize: 11
                                color: "#71717a"
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: qlCloseArea.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.18) : Qt.rgba(1.0, 1.0, 1.0, 0.08)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                font.pointSize: 16
                                color: "#f4f4f5"
                            }

                            MouseArea {
                                id: qlCloseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.quickLookWindow = null
                            }
                        }
                    }

                    // Expanded Preview Viewport
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: "#07080a"
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                        clip: true

                        Loader {
                            anchors.fill: parent
                            anchors.margins: 24
                            sourceComponent: {
                                const cat = root.getAppCategory(root.quickLookWindow?.app_id || "", root.quickLookWindow?.title || "");
                                switch (cat) {
                                case "terminal": return terminalSkeleton;
                                case "browser": return browserSkeleton;
                                case "media": return mediaSkeleton;
                                default: return genericSkeleton;
                                }
                            }
                        }
                    }

                    // Modal Footer
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        Rectangle {
                            height: 24
                            width: qlInfoRow.width + 16
                            radius: 12
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.06)

                            Row {
                                id: qlInfoRow
                                anchors.centerIn: parent
                                spacing: 8

                                StyledText {
                                    text: `Resolution: ${root.quickLookWindow?.w || 0} × ${root.quickLookWindow?.h || 0}`
                                    font.pixelSize: 11
                                    color: "#a1a1aa"
                                }
                                StyledText {
                                    text: `ID: #${root.quickLookWindow?.id || 0}`
                                    font.pixelSize: 11
                                    color: "#71717a"
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 24
                            width: qlHintText.width + 16
                            radius: 12
                            color: Qt.rgba(0.38, 0.65, 0.98, 0.15)
                            border.width: 1
                            border.color: Qt.rgba(0.38, 0.65, 0.98, 0.30)

                            StyledText {
                                id: qlHintText
                                anchors.centerIn: parent
                                text: "Press [Enter] to Activate  ·  [Space] to Close"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "#93c5fd"
                            }
                        }
                    }
                }
            }
        }
    }
}
