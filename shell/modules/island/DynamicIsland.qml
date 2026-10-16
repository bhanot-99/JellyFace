pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.utils

// Dynamic Island: Contextual floating status capsule at top center of the screen,
// modeled on the authentic Apple iPhone Dynamic Island UI/UX.
// Morphs smoothly between an ambient idle pill, an active media capsule (live equalizer bars),
// and an expanded interactive media card (scrubber, timestamps, tactile controls).
Scope {
    id: root

    // --- Tunables ---
    readonly property real compactWidthIdle: 130
    readonly property real compactHeightIdle: 32
    readonly property real compactWidthMedia: 210
    readonly property real compactHeightMedia: 36
    readonly property real expandedWidth: 370
    readonly property real expandedHeight: 166
    readonly property real expandedRadius: 36

    readonly property real windowSlack: 24
    readonly property real topMargin: 8

    readonly property int animDurationExpand: 420
    readonly property int animDurationCollapse: 300
    readonly property real animOvershoot: 0.7

    readonly property int autoCollapseDelay: 2500
    readonly property int positionPollInterval: 500

    // --- Color Palette (D10) ---
    readonly property color colBg: "#000000"
    readonly property color colTextPrimary: "#FFFFFF"
    readonly property color colTextSecondary: "#98989D"
    readonly property color colTextTertiary: "#8E8E93"
    readonly property color colEqGreen: "#30D158"
    readonly property color colAccentPink: "#FA586A"
    readonly property color colScrubTrack: "#38383A"
    readonly property color colArtBg: "#1C1C1E"

    // --- State & Media Bindings (A9, B7, C5) ---
    readonly property MprisPlayer player: Players.active
    readonly property bool isPlaying: !!player && player.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: !!player && (isPlaying || player.playbackState === MprisPlaybackState.Paused || (player.trackTitle && player.trackTitle.length > 0))
    readonly property bool wanted: !CosmicWindows.fullscreen
    readonly property string artUrl: player ? Players.getArtUrl(player) : ""
    readonly property bool hasUnknownLength: !player || !player.length || player.length <= 0 || player.length > 2147483647
    readonly property real trackLength: hasUnknownLength ? 0 : player.length
    readonly property bool canSeek: (player?.canSeek ?? false) && trackLength > 0 && !hasUnknownLength

    // Morph progress (0 = compact, 1 = expanded) driving content cross-fade (B9, D2)
    readonly property real morph: {
        const hMin = hasMedia ? compactHeightMedia : compactHeightIdle;
        const hMax = expandedHeight;
        return Math.max(0, Math.min(1, (islandCapsule.height - hMin) / (hMax - hMin)));
    }

    function lengthStr(length: real): string {
        if (!length || isNaN(length) || length < 0)
            return "0:00";
        const hours = Math.floor(length / 3600);
        const mins = Math.floor((length % 3600) / 60);
        const secs = Math.floor(length % 60).toString().padStart(2, "0");
        if (hours > 0)
            return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    onHasMediaChanged: {
        if (!hasMedia)
            islandCapsule.expanded = false;
    }

    // IPC Interface for automation, testing, and script control
    IpcHandler {
        function expand(): void {
            if (root.hasMedia)
                islandCapsule.expanded = true;
        }

        function forceExpand(): void {
            islandCapsule.expanded = true;
        }

        function collapse(): void {
            islandCapsule.expanded = false;
        }

        function toggle(): void {
            if (islandCapsule.expanded)
                islandCapsule.expanded = false;
            else if (root.hasMedia)
                islandCapsule.expanded = true;
        }

        function isExpanded(): string {
            return islandCapsule.expanded ? "1" : "0";
        }

        target: "island"
    }

    // A2: Ticking system clock for idle pill, active only when idle & visible
    SystemClock {
        id: sysClock

        precision: SystemClock.Minutes
        enabled: win.visible && !root.hasMedia
    }

    // B6: Position polling only while expanded & actively playing
    Timer {
        id: positionTimer

        interval: root.positionPollInterval
        running: root.isPlaying && islandCapsule.expanded && win.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    // B1: Fixed-size layer-shell window anchored to top edge only (prevents Wayland surface resize churn)
    StyledWindow {
        id: win

        // C1: Screen binding guarded against undefined on monitor hot-plug/unplug
        screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0] ?? null
        name: "dynamic-island"
        visible: root.wanted
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        margins.top: root.topMargin

        implicitWidth: root.expandedWidth + root.windowSlack
        implicitHeight: root.expandedHeight + root.windowSlack

        mask: Region {
            item: islandCapsule
        }

        onVisibleChanged: {
            if (!visible)
                islandCapsule.expanded = false;
        }

        // B10: Plain Rectangle instead of StyledRect (no extra loaders/colors)
        Rectangle {
            id: islandCapsule

            property bool expanded: false

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: expanded ? root.expandedWidth : (root.hasMedia ? root.compactWidthMedia : root.compactWidthIdle)
            height: expanded ? root.expandedHeight : (root.hasMedia ? root.compactHeightMedia : root.compactHeightIdle)
            radius: Math.min(height / 2, root.expandedRadius)
            color: root.colBg
            clip: true

            // D1: Asymmetric animation curves (Overshoot expand, clean cubic collapse)
            Behavior on width {
                NumberAnimation {
                    duration: islandCapsule.expanded ? root.animDurationExpand : root.animDurationCollapse
                    easing.type: islandCapsule.expanded ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: root.animOvershoot
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: islandCapsule.expanded ? root.animDurationExpand : root.animDurationCollapse
                    easing.type: islandCapsule.expanded ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: root.animOvershoot
                }
            }

            // A7: HoverHandler keeps card open while hovered; auto-collapse starts on leave
            HoverHandler {
                id: cardHover
            }

            Timer {
                id: collapseTimer

                interval: root.autoCollapseDelay
                running: false
                onTriggered: {
                    if (!cardHover.hovered)
                        islandCapsule.expanded = false;
                }
            }

            Connections {
                function onHoveredChanged(): void {
                    if (cardHover.hovered)
                        collapseTimer.stop();
                    else if (islandCapsule.expanded)
                        collapseTimer.restart();
                }

                target: cardHover
            }

            // Compact Pill View (Fades out in first 25% of morph)
            Item {
                id: compactView

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: islandCapsule.width
                height: islandCapsule.height
                opacity: root.morph < 0.25 ? Math.max(0, 1 - root.morph / 0.25) : 0
                visible: opacity > 0

                // 1. Idle Pill
                Item {
                    id: idlePill

                    anchors.fill: parent
                    visible: !root.hasMedia

                    MaterialIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "music_note"
                        color: root.colAccentPink
                        fontStyle: Tokens.font.icon.size(13).build()
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(sysClock.date, "hh:mm")
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: root.colTextPrimary
                    }
                }

                // 2. Active Media Pill
                Item {
                    id: mediaPill

                    anchors.fill: parent
                    visible: root.hasMedia

                    // Compact Album Artwork (A3, B7, C6)
                    Rectangle {
                        id: compactArtBox

                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        radius: 12
                        color: root.colArtBg

                        Item {
                            id: compactArtMask

                            anchors.fill: parent
                            layer.enabled: true
                            visible: false

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "white"
                            }
                        }

                        Image {
                            id: compactArtImg

                            anchors.fill: parent
                            source: root.artUrl
                            sourceSize: Qt.size(104, 104)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                            layer.enabled: true
                            layer.effect: Mask {
                                maskSource: compactArtMask
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "music_note"
                            color: root.colAccentPink
                            fontStyle: Tokens.font.icon.size(13).build()
                            visible: compactArtImg.status !== Image.Ready
                        }
                    }

                    // B4, C2, D11: Fixed-size Equalizer box with looping SequentialAnimations (no JS per tick)
                    Item {
                        id: eqBars

                        readonly property bool animRunning: root.isPlaying && !islandCapsule.expanded && win.visible

                        onAnimRunningChanged: {
                            if (!animRunning) {
                                bar0.height = 3.5;
                                bar1.height = 3.5;
                                bar2.height = 3.5;
                                bar3.height = 3.5;
                            }
                        }

                        width: 18
                        height: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: bar0

                            x: 0
                            width: 3
                            radius: 1.5
                            color: root.colEqGreen
                            anchors.bottom: parent.bottom
                            height: 3.5

                            SequentialAnimation on height {
                                running: eqBars.animRunning
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 13
                                    duration: 340
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 4
                                    duration: 380
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Rectangle {
                            id: bar1

                            x: 5
                            width: 3
                            radius: 1.5
                            color: root.colEqGreen
                            anchors.bottom: parent.bottom
                            height: 3.5

                            SequentialAnimation on height {
                                running: eqBars.animRunning
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 15
                                    duration: 440
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 5
                                    duration: 410
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Rectangle {
                            id: bar2

                            x: 10
                            width: 3
                            radius: 1.5
                            color: root.colEqGreen
                            anchors.bottom: parent.bottom
                            height: 3.5

                            SequentialAnimation on height {
                                running: eqBars.animRunning
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 12
                                    duration: 310
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 3.5
                                    duration: 350
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Rectangle {
                            id: bar3

                            x: 15
                            width: 3
                            radius: 1.5
                            color: root.colEqGreen
                            anchors.bottom: parent.bottom
                            height: 3.5

                            SequentialAnimation on height {
                                running: eqBars.animRunning
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 14
                                    duration: 480
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 4
                                    duration: 450
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }

                // A4: Compact tap/hover area expands card only when media exists
                Timer {
                    id: expandHoverTimer

                    interval: 200
                    onTriggered: {
                        if (root.hasMedia && !islandCapsule.expanded) {
                            islandCapsule.expanded = true;
                            if (!cardHover.hovered)
                                collapseTimer.restart();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !islandCapsule.expanded && root.hasMedia
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        expandHoverTimer.stop();
                        islandCapsule.expanded = true;
                        if (!cardHover.hovered)
                            collapseTimer.restart();
                    }
                    onEntered: {
                        if (root.hasMedia && !islandCapsule.expanded)
                            expandHoverTimer.restart();
                    }
                    onExited: {
                        expandHoverTimer.stop();
                    }
                }
            }

            // B3, D3: Fixed-size Expanded Bento Card (pinned top-center; clip reveals it without layout reflow)
            Item {
                id: expandedView

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 14
                width: root.expandedWidth - 28
                height: root.expandedHeight - 28
                opacity: root.morph > 0.45 ? Math.min(1, (root.morph - 0.45) / 0.55) : 0
                visible: opacity > 0

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Tier 1: Media Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Large Album Artwork (A3, B7, C6) - Perfect Circle
                        Rectangle {
                            id: largeArtBox

                            width: 52
                            height: 52
                            radius: 26
                            color: root.colArtBg

                            Item {
                                id: largeArtMask

                                anchors.fill: parent
                                layer.enabled: true
                                visible: false

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "white"
                                }
                            }

                            Image {
                                id: expandedArtImg

                                anchors.fill: parent
                                source: root.artUrl
                                sourceSize: Qt.size(104, 104)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                                layer.enabled: true
                                layer.effect: Mask {
                                    maskSource: largeArtMask
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "album"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                fontStyle: Tokens.font.icon.size(26).build()
                                visible: expandedArtImg.status !== Image.Ready
                            }
                        }

                        // Track Title & Artist (D9: animate for smooth track fade)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.player?.trackTitle || Tr.tr("Ready to Play")
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: root.colTextPrimary
                                elide: Text.ElideRight
                                animate: true
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.player?.trackArtist || root.player?.identity || Tr.tr("JellyFace Island")
                                font.pixelSize: 12
                                color: root.colTextSecondary
                                elide: Text.ElideRight
                                animate: true
                            }
                        }

                        // A8: Non-interactive audio route indicator badge
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.10)
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "airplay"
                                color: root.colEqGreen
                                fontStyle: Tokens.font.icon.size(14).build()
                            }
                        }
                    }

                    // Tier 2: Timeline Scrubber (A5, A6, C5, D6, D7)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: root.lengthStr(scrubBar.dragging ? scrubBar.dragProgress * root.trackLength : (root.player?.position ?? 0))
                            font.pixelSize: 11
                            color: root.colTextTertiary
                            Layout.preferredWidth: 44
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            id: scrubBar

                            property bool dragging: false
                            property real dragProgress: 0
                            property bool holdRelease: false

                            readonly property real currentProgress: {
                                if (root.trackLength <= 0)
                                    return 0;
                                if (dragging || holdRelease)
                                    return dragProgress;
                                return Math.max(0, Math.min(1, (root.player?.position ?? 0) / root.trackLength));
                            }

                            Layout.fillWidth: true
                            implicitHeight: 20

                            Timer {
                                id: scrubHoldTimer

                                interval: 350
                                onTriggered: scrubBar.holdRelease = false
                            }

                            // Interactive Scrubber Track (thickens 4 -> 8 px on hover/press when seekable)
                            Rectangle {
                                id: trackBg

                                anchors.centerIn: parent
                                width: parent.width
                                height: (root.canSeek && (scrubArea.containsMouse || scrubBar.dragging)) ? 8 : 4
                                radius: height / 2
                                color: root.colScrubTrack

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.colTextPrimary
                                    width: Math.max(0, Math.min(parent.width, parent.width * scrubBar.currentProgress))

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.horizontalCenter: parent.right
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: root.colTextPrimary
                                        visible: root.canSeek && (scrubArea.containsMouse || scrubBar.dragging)
                                    }
                                }
                            }

                            MouseArea {
                                id: scrubArea

                                anchors.fill: parent
                                enabled: root.canSeek
                                hoverEnabled: true
                                cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onPressed: mouse => {
                                    scrubBar.dragging = true;
                                    scrubBar.holdRelease = false;
                                    scrubHoldTimer.stop();
                                    scrubBar.dragProgress = Math.max(0, Math.min(1, mouse.x / width));
                                }

                                onPositionChanged: mouse => {
                                    if (scrubBar.dragging)
                                        scrubBar.dragProgress = Math.max(0, Math.min(1, mouse.x / width));
                                }

                                onReleased: mouse => {
                                    if (scrubBar.dragging) {
                                        scrubBar.dragProgress = Math.max(0, Math.min(1, mouse.x / width));
                                        scrubBar.dragging = false;
                                        if (root.player && root.trackLength > 0) {
                                            root.player.position = scrubBar.dragProgress * root.trackLength;
                                            scrubBar.holdRelease = true;
                                            scrubHoldTimer.restart();
                                        }
                                    }
                                }

                                onCanceled: {
                                    scrubBar.dragging = false;
                                    scrubBar.holdRelease = false;
                                }
                            }
                        }

                        StyledText {
                            text: root.trackLength > 0 ? ("-" + root.lengthStr(Math.max(0, root.trackLength - (scrubBar.dragging ? scrubBar.dragProgress * root.trackLength : (root.player?.position ?? 0))))) : "--:--"
                            font.pixelSize: 11
                            color: root.colTextTertiary
                            Layout.preferredWidth: 44
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    // Tier 3: Controls Row (D4, D5: Centered transport group, pinned chevron)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 44

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 24

                            PressableIcon {
                                icon: "skip_previous"
                                pointSize: 22
                                enabled: root.player?.canGoPrevious ?? false
                                onClicked: root.player?.previous()
                            }

                            // Prominent Apple Play/Pause Button (A1, A5, D8)
                            Rectangle {
                                id: playBtn

                                width: 44
                                height: 44
                                radius: 22
                                color: root.colTextPrimary
                                enabled: root.player?.canTogglePlaying ?? false
                                opacity: enabled ? (playArea.containsMouse ? 1.0 : 0.92) : 0.35
                                scale: playArea.pressed && enabled ? 0.94 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 90
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 90
                                    }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: root.isPlaying ? "pause" : "play_arrow"
                                    color: root.colBg
                                    fontStyle: Tokens.font.icon.size(24).build()
                                }

                                MouseArea {
                                    id: playArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: playBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (playBtn.enabled) root.player?.togglePlaying()
                                }
                            }

                            PressableIcon {
                                icon: "skip_next"
                                pointSize: 22
                                enabled: root.player?.canGoNext ?? false
                                onClicked: root.player?.next()
                            }
                        }

                        PressableIcon {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "expand_less"
                            pointSize: 18
                            color: root.colTextTertiary
                            activeColor: root.colTextPrimary
                            onClicked: islandCapsule.expanded = false
                        }
                    }
                }
            }
        }
    }

    // B13: Reusable pressable icon component with scale & opacity feedback
    component PressableIcon: Item {
        id: btn

        property string icon: ""
        property int pointSize: 20
        property color color: root.colTextPrimary
        property color activeColor: "#FFFFFF"
        property bool enabled: true

        signal clicked()

        implicitWidth: pointSize + 14
        implicitHeight: pointSize + 14
        opacity: enabled ? (mArea.containsMouse ? 1.0 : 0.85) : 0.35
        scale: mArea.pressed && enabled ? 0.88 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 90
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            fontStyle: Tokens.font.icon.size(btn.pointSize).build()
            color: mArea.containsMouse ? btn.activeColor : btn.color
        }

        MouseArea {
            id: mArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.enabled) btn.clicked()
        }
    }
}
