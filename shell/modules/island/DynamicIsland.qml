pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Jellyface.Config
import Jellyface.I18n
import Jellyface.Images
import Jellyface.Services
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services

// Dynamic Island: Contextual floating status capsule at top center of the screen,
// modeled on the authentic Apple iPhone Dynamic Island UI/UX.
//  - Empty black idle pill, springs between sizes, blur/scale content transitions
//  - Live activities: media (cava-driven, artwork-tinted equaliser), timer, notification, mute/volume/charging
//  - Two activities at once split into two bubbles joined by a gooey neck
//  - Gestures: tap (open source app / expand), long-press or hover (expand), swipe up (dismiss / collapse)
Scope {
    id: root

    // --- Tunables ---
    // Idle matches the iPhone 14 Pro cutout: an empty black pill (set false to hide it entirely)
    readonly property bool idleVisible: true
    // Desktop affordance on top of iPhone's long-press: hovering a compact activity expands it
    readonly property bool hoverExpand: true
    // Pause this long over a bubble before the card opens, so a quick tap or swipe still reaches the bubble
    readonly property int hoverDwellMs: 450
    readonly property bool showNotifications: true
    readonly property real compactWidthIdle: 126
    readonly property real compactHeightIdle: 37
    readonly property real compactWidthActive: 210
    readonly property real compactHeightActive: 36
    readonly property real splitPrimaryWidth: 164
    readonly property real splitSecondWidth: 116
    readonly property real splitGap: 8
    readonly property real expandedWidth: 370
    readonly property real expandedHeightMax: 166
    readonly property real expandedRadius: 36

    readonly property real windowSlack: 24
    readonly property real topMargin: 8

    // Spring physics for the morph: lower damping = more bounce
    readonly property real springStiffness: 4.2
    readonly property real springDamping: 0.3
    readonly property real springDampingCollapse: 0.42
    readonly property int hudDuration: 1800
    readonly property int notifDuration: 4500
    readonly property real swipeThreshold: 14

    readonly property int autoCollapseDelay: 2500
    readonly property int positionPollInterval: 500

    // --- Color Palette (D10) ---
    property color colBg: "#000000"
    property color colTextPrimary: "#FFFFFF"
    property color colTextSecondary: "#98989D"
    property color colTextTertiary: "#8E8E93"
    property color colEqGreen: "#30D158"
    property color colAccentPink: "#FA586A"
    property color colTimer: "#FF9F0A"
    property color colDanger: "#FF453A"
    property color colScrubTrack: "#38383A"
    property color colArtBg: "#1C1C1E"

    // --- Media ---
    readonly property MprisPlayer player: Players.active
    readonly property bool isPlaying: !!player && player.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: !!player && (isPlaying || player.playbackState === MprisPlaybackState.Paused || (player.trackTitle && player.trackTitle.length > 0))
    property bool mediaDismissed: false
    readonly property bool mediaActive: hasMedia && !mediaDismissed
    readonly property string artUrl: player ? Players.getArtUrl(player) : ""
    readonly property bool hasUnknownLength: !player || !player.length || player.length <= 0 || player.length > 2147483647
    readonly property real trackLength: hasUnknownLength ? 0 : player.length
    readonly property bool canSeek: (player?.canSeek ?? false) && trackLength > 0 && !hasUnknownLength

    // --- Shell state ---
    readonly property ScreenState activeScreenState: ShellState.forScreen(win.screen) ?? ShellState.forActive()
    readonly property bool dashboardOpen: activeScreenState?.dashboard ?? false
    readonly property bool appDrawerOpen: JellyPanel.open
    // set by an interface that covers the top centre with something of its own (Drift's Today)
    property bool hidden: false
    readonly property bool suppressed: dashboardOpen || appDrawerOpen || hidden

    // --- Transient system activity ("mute" | "volume" | "charge" | "") like iPhone's silent-mode / charging pills ---
    property string hud: ""
    property bool hudReady: false
    readonly property bool hasHud: hud !== ""
    readonly property real batteryPct: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
    readonly property string hudIcon: hud === "mute" ? (Audio.muted ? "volume_off" : "volume_up") : hud === "volume" ? (Audio.volume > 0.5 ? "volume_up" : "volume_down") : hud === "charge" ? "bolt" : ""
    readonly property string hudText: hud === "mute" ? (Audio.muted ? Tr.tr("Muted") : Tr.tr("Unmuted")) : hud === "volume" ? Math.round(Audio.volume * 100) + "%" : hud === "charge" ? batteryPct + "%" : ""
    readonly property color hudColor: hud === "charge" ? colEqGreen : (hud === "mute" && Audio.muted) ? colAccentPink : colTextPrimary

    // --- Notification activity (snapshot so the pill outlives the NotifData) ---
    property bool hasNotif: false
    property var notifData: ({
            summary: "",
            body: "",
            appName: "",
            icon: ""
        })

    // --- Timer activity (started over IPC: qs ipc call island startTimer 300) ---
    property real timerEnd: 0
    property int timerTotal: 0
    property int timerLeft: 0
    property bool timerRunning: false
    property bool timerDone: false
    property bool timerHidden: false
    readonly property bool timerActive: (timerRunning || timerDone) && !timerHidden
    readonly property string timerText: timerDone ? Tr.tr("Done") : lengthStr(timerLeft)
    readonly property real timerProgress: timerTotal > 0 ? Math.max(0, Math.min(1, timerLeft / timerTotal)) : 0

    // --- Activity routing: up to two activities, media always takes the left bubble when paired ---
    readonly property string otherKind: hasHud ? "hud" : hasNotif ? "notif" : timerActive ? "timer" : ""
    readonly property bool split: mediaActive && otherKind !== ""
    readonly property string primaryKind: mediaActive ? "media" : otherKind
    readonly property string secondKind: split ? otherKind : ""
    readonly property bool compactActive: primaryKind !== ""
    property string secondKindShown: "hud"
    onSecondKindChanged: {
        if (secondKind !== "")
            secondKindShown = secondKind;
    }

    // Kind currently shown by the expanded card
    property string expandedKind: "media"
    readonly property real expandedHeight: expandedKind === "media" ? 166 : expandedKind === "timer" ? 118 : 112
    readonly property color artTint: primaryPill.tint
    readonly property color glowColor: expandedKind === "timer" ? colTimer : expandedKind === "media" ? artTint : "transparent"

    // Morph progress (0 = compact, 1 = expanded) driving content cross-fade (B9, D2)
    readonly property real morph: {
        const hMin = compactActive ? compactHeightActive : compactHeightIdle;
        const hMax = expandedHeight;
        return Math.max(0, Math.min(1, (islandCapsule.baseHeight - hMin) / (hMax - hMin)));
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

    function showHud(kind: string): void {
        if (!hudReady || suppressed || islandCapsule.expanded)
            return;
        hud = kind;
        hudTimer.restart();
    }

    function showNotif(n: var): void {
        if (!showNotifications || suppressed || islandCapsule.expanded)
            return;
        notifData = {
            summary: n.summary ?? "",
            body: n.body ?? "",
            appName: n.appName ?? "",
            icon: n.image || (n.appIcon ? Quickshell.iconPath(n.appIcon, true) : "")
        };
        hasNotif = true;
        notifTimer.restart();
    }

    function startTimer(seconds: int): void {
        if (seconds <= 0)
            return;
        timerTotal = seconds;
        timerLeft = seconds;
        timerEnd = Date.now() + seconds * 1000;
        timerRunning = true;
        timerDone = false;
        timerHidden = false;
        timerDoneTimer.stop();
    }

    function cancelTimer(): void {
        timerRunning = false;
        timerDone = false;
        timerDoneTimer.stop();
        if (islandCapsule.expanded && expandedKind === "timer")
            islandCapsule.expanded = false;
    }

    function expandFor(kind: string): void {
        if (kind === "media" && !hasMedia)
            return;
        if (kind !== "media" && kind !== "timer" && kind !== "notif")
            return;
        if ((kind === "timer" && !timerActive) || (kind === "notif" && !hasNotif))
            return;
        if (islandCapsule.expanded && expandedKind === kind)
            return;
        expandedKind = kind;
        islandCapsule.expanded = true;
        if (!cardHover.hovered)
            collapseTimer.restart();
    }

    // iPhone: tapping a compact activity opens its source app
    function activate(kind: string): void {
        if (kind === "media") {
            const entry = player?.desktopEntry ?? "";
            if (entry !== "")
                Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", entry]);
            else
                expandFor("media");
        } else {
            expandFor(kind);
        }
    }

    // Swipe up on a compact activity tucks it away until it changes
    function dismiss(kind: string): void {
        if (kind === "media")
            mediaDismissed = true;
        else if (kind === "hud")
            hud = "";
        else if (kind === "notif")
            hasNotif = false;
        else if (kind === "timer")
            timerHidden = true;
    }

    onHasMediaChanged: {
        if (!hasMedia) {
            mediaDismissed = false;
            if (islandCapsule.expanded && expandedKind === "media")
                islandCapsule.expanded = false;
        }
    }

    onSuppressedChanged: {
        if (suppressed) {
            islandCapsule.expanded = false;
            hud = "";
            hasNotif = false;
        }
    }

    // A new track or resuming playback brings a dismissed media activity back
    Connections {
        function onTrackTitleChanged(): void {
            root.mediaDismissed = false;
        }

        function onPlaybackStateChanged(): void {
            if (root.isPlaying)
                root.mediaDismissed = false;
        }

        target: root.player
        ignoreUnknownSignals: true
    }

    // IPC Interface for automation, testing, and script control
    IpcHandler {
        function expand(): void {
            root.expandFor("media");
        }

        function forceExpand(): void {
            islandCapsule.expanded = true;
        }

        function expandKind(kind: string): void {
            root.expandFor(kind);
        }

        function collapse(): void {
            islandCapsule.expanded = false;
        }

        function toggle(): void {
            if (islandCapsule.expanded)
                islandCapsule.expanded = false;
            else
                root.expandFor("media");
        }

        function isExpanded(): string {
            return islandCapsule.expanded ? "1" : "0";
        }

        function startTimer(seconds: int): void {
            root.startTimer(seconds);
        }

        function cancelTimer(): void {
            root.cancelTimer();
        }

        function notify(summary: string, body: string): void {
            root.showNotif({
                summary: summary,
                body: body,
                appName: "",
                appIcon: ""
            });
        }

        target: "island"
    }

    Timer {
        id: hudTimer

        interval: root.hudDuration
        onTriggered: root.hud = ""
    }

    Timer {
        id: notifTimer

        interval: root.notifDuration
        onTriggered: root.hasNotif = false
    }

    Timer {
        id: timerTick

        interval: 250
        running: root.timerRunning
        repeat: true
        onTriggered: {
            const left = Math.ceil((root.timerEnd - Date.now()) / 1000);
            if (left <= 0) {
                root.timerLeft = 0;
                root.timerRunning = false;
                root.timerDone = true;
                timerDoneTimer.restart();
            } else {
                root.timerLeft = left;
            }
        }
    }

    Timer {
        id: timerDoneTimer

        interval: 6000
        onTriggered: root.timerDone = false
    }

    // Skip the initial property settle at startup so the HUD only reacts to real changes
    Timer {
        interval: 1500
        running: true
        onTriggered: root.hudReady = true
    }

    Connections {
        function onMutedChanged(): void {
            root.showHud("mute");
        }

        function onVolumeChanged(): void {
            if (!Audio.muted)
                root.showHud("volume");
        }

        target: Audio
    }

    Connections {
        function onOnBatteryChanged(): void {
            if (UPower.displayDevice.ready && !UPower.onBattery)
                root.showHud("charge");
        }

        target: UPower
    }

    Connections {
        function onListChanged(): void {
            if (!root.hudReady)
                return;
            const n = Notifs.list[0];
            if (n && n !== root.lastNotif) {
                root.lastNotif = n;
                if (n.popup && Date.now() - n.time.getTime() < 3000)
                    root.showNotif(n);
            }
        }

        target: Notifs
    }

    property var lastNotif: null

    // B6: Position polling only while expanded & actively playing
    Timer {
        id: positionTimer

        interval: root.positionPollInterval
        running: root.isPlaying && islandCapsule.expanded && root.expandedKind === "media" && win.visible
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
        visible: !root.suppressed || islandCapsule.opacity > 0
        // Top, not Overlay: COSMIC itself draws a fullscreen window over the Top layer, in the same frame as the
        // switch. On Overlay the island had to be unmapped when the shell heard about the fullscreen window (a helper
        // line and a QML update later), so it flashed over the video on every window, workspace or tab switch.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        margins.top: root.topMargin

        implicitWidth: root.expandedWidth + root.windowSlack
        implicitHeight: root.expandedHeightMax + root.windowSlack

        mask: Region {
            item: islandCapsule

            Region {
                item: secondCapsule
            }
        }

        onVisibleChanged: {
            if (!visible)
                islandCapsule.expanded = false;
        }

        // an open card would otherwise still be open (and polling the player) behind the fullscreen window
        Connections {
            function onFullscreenChanged(): void {
                if (CosmicWindows.fullscreen)
                    islandCapsule.expanded = false;
            }

            target: CosmicWindows
        }

        // Gooey neck joining the two bubbles: full height while they overlap, pinching off as the gap opens
        Rectangle {
            id: bridge

            readonly property real gap: secondCapsule.x - (islandCapsule.x + islandCapsule.width)
            readonly property real neck: Math.max(0, Math.min(1, (root.splitGap - 1 - gap) / 10))

            visible: secondCapsule.width > 2 && !islandCapsule.expanded && neck > 0.01
            x: islandCapsule.x + islandCapsule.width - 12
            width: Math.max(0, gap + 24)
            height: Math.max(0, Math.min(islandCapsule.height, secondCapsule.height) * neck)
            y: (islandCapsule.height - height) / 2
            radius: height / 2
            color: root.colBg
            opacity: islandCapsule.opacity
        }

        // Secondary bubble: appears when a second activity runs next to media
        Rectangle {
            id: secondCapsule

            readonly property bool shown: root.split && !islandCapsule.expanded

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: shown ? (root.splitPrimaryWidth + root.splitGap) / 2 : 0
            anchors.top: parent.top
            width: shown ? root.splitSecondWidth : 0
            height: root.compactHeightActive
            radius: height / 2
            color: root.colBg
            clip: true
            visible: width > 1
            opacity: root.suppressed ? 0 : 1
            enabled: shown

            Behavior on anchors.horizontalCenterOffset {
                SpringAnimation {
                    spring: root.springStiffness
                    damping: secondCapsule.shown ? root.springDamping : root.springDampingCollapse
                    epsilon: 0.25
                }
            }

            Behavior on width {
                SpringAnimation {
                    spring: root.springStiffness
                    damping: secondCapsule.shown ? root.springDamping : root.springDampingCollapse
                    epsilon: 0.25
                }
            }

            transform: Translate {
                y: gSecond.dragY * 0.6

                Behavior on y {
                    enabled: !gSecond.dragging
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutBack
                    }
                }
            }

            Item {
                id: secondView

                anchors.horizontalCenter: parent.horizontalCenter
                width: root.splitSecondWidth
                height: parent.height
                opacity: Math.min(1, secondCapsule.width / root.splitSecondWidth)

                Pill {
                    anchors.fill: parent
                    kind: root.secondKindShown
                }

                Gestures {
                    id: gSecond

                    onTapped: root.activate(root.secondKindShown)
                    onHeld: root.expandFor(root.secondKindShown)
                    onHoverDwell: if (root.hoverExpand) root.expandFor(root.secondKindShown)
                    onSwipedUp: root.dismiss(root.secondKindShown)
                }
            }
        }

        // B10: Plain Rectangle instead of StyledRect (no extra loaders/colors)
        Rectangle {
            id: islandCapsule

            property bool expanded: false
            // 0 → 1 over the dashboard's hover wait (services/DashboardPeek): the island is pulled down towards it
            property real peek: DashboardPeek.active && !expanded && !root.suppressed ? 1 : 0
            // the morph between states springs; the peek is added on top so it tracks the wait exactly
            property real baseHeight: expanded ? root.expandedHeight : (root.compactActive ? root.compactHeightActive : root.compactHeightIdle)

            Behavior on peek {
                NumberAnimation {
                    duration: DashboardPeek.active ? DashboardPeek.dwell : 260
                    easing.type: DashboardPeek.active ? Easing.OutCubic : Easing.OutBack
                }
            }

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: secondCapsule.shown ? -(root.splitGap + root.splitSecondWidth) / 2 : 0
            anchors.top: parent.top
            width: expanded ? root.expandedWidth : root.split ? root.splitPrimaryWidth : (root.compactActive ? root.compactWidthActive : root.compactWidthIdle)
            height: baseHeight + peek * 14
            radius: Math.min(height / 2, root.expandedRadius)
            color: root.colBg
            clip: true
            opacity: root.suppressed || (!root.idleVisible && !root.compactActive && !expanded) ? 0 : 1
            scale: root.suppressed ? 0.85 : 1
            enabled: !root.suppressed

            transform: [
                Translate {
                    id: tuckTranslate

                    y: root.suppressed ? -islandCapsule.height - 16 : 0

                    Behavior on y {
                        NumberAnimation {
                            duration: root.suppressed ? 220 : 350
                            easing.type: root.suppressed ? Easing.InCubic : Easing.OutBack
                            easing.overshoot: 0.6
                        }
                    }
                },
                Translate {
                    y: Math.min(0, gPrimary.dragY, swipeCollapse.dragY) * 0.6

                    Behavior on y {
                        enabled: !gPrimary.dragging && !swipeCollapse.active
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                        }
                    }
                }
            ]

            onExpandedChanged: {
                if (expanded) {
                    notifTimer.stop();
                    hudTimer.stop();
                    root.hud = "";
                } else if (root.hasNotif) {
                    // Expanding stopped the notification timer: dismiss it if it was the open card, else resume it
                    if (root.expandedKind === "notif")
                        root.hasNotif = false;
                    else
                        notifTimer.restart();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.suppressed ? 180 : 250
                    easing.type: Easing.InOutQuad
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: root.suppressed ? 220 : 350
                    easing.type: root.suppressed ? Easing.InQuad : Easing.OutBack
                    easing.overshoot: 0.6
                }
            }

            Behavior on anchors.horizontalCenterOffset {
                SpringAnimation {
                    spring: root.springStiffness
                    damping: secondCapsule.shown ? root.springDamping : root.springDampingCollapse
                    epsilon: 0.25
                }
            }

            // D1: Spring physics (bouncy on expand, tighter on collapse)
            Behavior on width {
                SpringAnimation {
                    spring: root.springStiffness
                    damping: islandCapsule.expanded ? root.springDamping : root.springDampingCollapse
                    epsilon: 0.25
                }
            }

            Behavior on baseHeight {
                SpringAnimation {
                    spring: root.springStiffness
                    damping: islandCapsule.expanded ? root.springDamping : root.springDampingCollapse
                    epsilon: 0.25
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

            // Swipe up on the expanded card collapses it (child controls grab their own presses)
            DragHandler {
                id: swipeCollapse

                property real dragY: 0

                enabled: islandCapsule.expanded
                target: null
                xAxis.enabled: false
                // Do not steal presses from the scrubber and buttons
                grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything
                onTranslationChanged: dragY = Math.min(0, translation.y)
                onActiveChanged: {
                    if (!active) {
                        if (dragY < -root.swipeThreshold)
                            islandCapsule.expanded = false;
                        dragY = 0;
                    }
                }
            }

            // Artwork / timer tinted glow behind the expanded card
            Rectangle {
                anchors.fill: parent
                radius: islandCapsule.radius
                opacity: root.morph * 0.85
                visible: opacity > 0.01 && root.expandedKind !== "notif"

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.5)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.0)
                    }
                }
            }

            // Compact Pill View (blurs/scales out in first 25% of morph)
            Item {
                id: compactView

                readonly property real blurAmt: root.morph < 0.25 ? Math.min(1, root.morph / 0.25) : 0

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: islandCapsule.width
                height: islandCapsule.baseHeight
                opacity: root.morph < 0.25 ? Math.max(0, 1 - root.morph / 0.25) : 0
                scale: 1 - 0.18 * blurAmt
                transformOrigin: Item.Top
                visible: opacity > 0
                layer.enabled: blurAmt > 0.02
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 24
                    blur: compactView.blurAmt
                }

                Pill {
                    id: primaryPill

                    anchors.fill: parent
                    kind: root.primaryKind
                    tracksArt: true
                }

                Gestures {
                    id: gPrimary

                    enabled: !islandCapsule.expanded
                    onTapped: root.activate(root.primaryKind)
                    onHeld: root.expandFor(root.primaryKind)
                    onHoverDwell: if (root.hoverExpand) root.expandFor(root.primaryKind)
                    onSwipedUp: root.dismiss(root.primaryKind)
                }
            }

            // B3, D3: Fixed-size Expanded Cards (pinned top-center; clip reveals them without layout reflow)
            // --- Media card ---
            Item {
                id: expandedView

                readonly property real blurAmt: root.morph < 1 ? Math.min(0.7, (1 - root.morph) * 1.2) : 0

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 14
                width: root.expandedWidth - 28
                height: 166 - 28
                opacity: root.expandedKind === "media" && root.morph > 0.45 ? Math.min(1, (root.morph - 0.45) / 0.55) : 0
                scale: 0.88 + 0.12 * Math.min(1, root.morph)
                transformOrigin: Item.Top
                visible: opacity > 0
                layer.enabled: visible && blurAmt > 0.02
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 24
                    blur: expandedView.blurAmt
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Tier 1: Media Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Large Album Artwork - Perfect Circle
                        RoundImage {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            source: root.artUrl
                            fallback: "album"
                            fallbackColor: Qt.alpha(root.colTextPrimary, 0.4)
                            fallbackSize: 26
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
                            color: Qt.alpha(root.colTextPrimary, 0.10)
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "airplay"
                                color: root.artTint
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

            // --- Timer card ---
            Item {
                id: timerCard

                readonly property real blurAmt: root.morph < 1 ? Math.min(0.7, (1 - root.morph) * 1.2) : 0

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 14
                width: root.expandedWidth - 28
                height: 118 - 28
                opacity: root.expandedKind === "timer" && root.morph > 0.45 ? Math.min(1, (root.morph - 0.45) / 0.55) : 0
                scale: 0.88 + 0.12 * Math.min(1, root.morph)
                transformOrigin: Item.Top
                visible: opacity > 0
                layer.enabled: visible && blurAmt > 0.02
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 24
                    blur: timerCard.blurAmt
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            spacing: 0

                            RowLayout {
                                spacing: 6

                                MaterialIcon {
                                    text: "timer"
                                    color: root.colTimer
                                    fontStyle: Tokens.font.icon.size(16).build()
                                }

                                StyledText {
                                    text: Tr.tr("Timer")
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: root.colTimer
                                }
                            }

                            StyledText {
                                text: root.timerText
                                font.pixelSize: 34
                                font.weight: Font.DemiBold
                                color: root.colTextPrimary
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Cancel
                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 22
                            color: Qt.rgba(1, 0.27, 0.23, cancelArea.pressed ? 0.45 : 0.28)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: root.colDanger
                                fontStyle: Tokens.font.icon.size(22).build()
                            }

                            MouseArea {
                                id: cancelArea

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelTimer()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: root.colScrubTrack

                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: root.colTimer
                            width: parent.width * root.timerProgress
                        }
                    }
                }
            }

            // --- Notification card ---
            Item {
                id: notifCard

                readonly property real blurAmt: root.morph < 1 ? Math.min(0.7, (1 - root.morph) * 1.2) : 0

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 14
                width: root.expandedWidth - 28
                height: 112 - 28
                opacity: root.expandedKind === "notif" && root.morph > 0.45 ? Math.min(1, (root.morph - 0.45) / 0.55) : 0
                scale: 0.88 + 0.12 * Math.min(1, root.morph)
                transformOrigin: Item.Top
                visible: opacity > 0
                layer.enabled: visible && blurAmt > 0.02
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 24
                    blur: notifCard.blurAmt
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 12

                    RoundImage {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignTop
                        source: root.notifData.icon
                        fallback: "notifications"
                        fallbackColor: Qt.alpha(root.colTextPrimary, 0.6)
                        fallbackSize: 22
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.notifData.appName
                            textFormat: Text.PlainText
                            visible: text !== ""
                            font.pixelSize: 11
                            color: root.colTextTertiary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.notifData.summary
                            textFormat: Text.PlainText
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: root.colTextPrimary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.notifData.body
                            textFormat: Text.PlainText
                            visible: text !== ""
                            font.pixelSize: 12
                            color: root.colTextSecondary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    PressableIcon {
                        Layout.alignment: Qt.AlignTop
                        icon: "close"
                        pointSize: 16
                        color: root.colTextTertiary
                        activeColor: root.colTextPrimary
                        onClicked: islandCapsule.expanded = false
                    }
                }
            }
        }
    }

    // Tap / long-press / hover-dwell / swipe-up recogniser for a compact bubble
    component Gestures: Item {
        id: g

        property real dragY: 0
        readonly property bool dragging: dragH.active

        signal tapped
        signal held
        signal hoverDwell
        signal swipedUp

        anchors.fill: parent
        onEnabledChanged: if (!enabled) dwellTimer.stop()

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered)
                    dwellTimer.restart();
                else
                    dwellTimer.stop();
            }
        }

        Timer {
            id: dwellTimer

            interval: root.hoverDwellMs
            onTriggered: g.hoverDwell()
        }

        TapHandler {
            longPressThreshold: 0.45
            onTapped: g.tapped()
            onLongPressed: g.held()
        }

        DragHandler {
            id: dragH

            target: null
            xAxis.enabled: false
            onTranslationChanged: g.dragY = Math.min(0, translation.y)
            onActiveChanged: {
                if (!active) {
                    if (g.dragY < -root.swipeThreshold)
                        g.swipedUp();
                    g.dragY = 0;
                }
            }
        }
    }

    // Circular image with a glyph fallback
    component RoundImage: Item {
        id: ri

        property alias source: img.source
        property string fallback: "music_note"
        property color fallbackColor: root.colAccentPink
        property int fallbackSize: 13
        property alias image: img

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.colArtBg
        }

        Item {
            id: maskItem

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
            id: img

            anchors.fill: parent
            sourceSize: Qt.size(104, 104)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: Mask {
                maskSource: maskItem
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: ri.fallback
            color: ri.fallbackColor
            fontStyle: Tokens.font.icon.size(ri.fallbackSize).build()
            visible: img.status !== Image.Ready
        }
    }

    // One equaliser bar: driven by cava when it has signal, otherwise a looping fake animation
    component EqBar: Rectangle {
        id: bar

        property int idx: 0
        property real peak: 13
        property int durUp: 340
        property int durDown: 380
        property real anim: 3.5
        property real level: 0
        property bool live: false
        property bool running: false

        anchors.bottom: parent.bottom
        width: 3
        radius: 1.5
        x: idx * 5
        height: running ? (live ? 3.5 + level * (parent.height - 3.5) : anim) : 3.5

        Behavior on height {
            enabled: bar.live
            NumberAnimation {
                duration: 70
            }
        }

        SequentialAnimation on anim {
            running: bar.running && !bar.live
            loops: Animation.Infinite

            NumberAnimation {
                to: bar.peak
                duration: bar.durUp
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 4
                duration: bar.durDown
                easing.type: Easing.InOutSine
            }
        }
    }

    // Compact content for any activity kind ("media" | "hud" | "timer" | "notif" | "")
    component Pill: Item {
        id: pill

        required property string kind
        property bool tracksArt: false

        readonly property bool eqRunning: kind === "media" && root.isPlaying && !islandCapsule.expanded && win.visible
        readonly property var cavaValues: Audio.cava.values
        readonly property bool cavaLive: {
            const v = cavaValues;
            if (!v || v.length === 0)
                return false;
            let s = 0;
            for (let i = 0; i < v.length; i++)
                s += v[i];
            return s > 0.02;
        }
        readonly property color tint: {
            const c = analyser.dominantColour;
            if (c.r + c.g + c.b < 0.03)
                return root.colEqGreen;
            return c.hslLightness < 0.55 ? Qt.hsla(Math.max(0, c.hslHue), Math.max(c.hslSaturation, 0.55), 0.62, 1) : c;
        }

        function level(i: int): real {
            const v = cavaValues;
            const n = v ? v.length : 0;
            if (n === 0)
                return 0;
            const per = Math.max(1, Math.floor(n / 4));
            let s = 0;
            let c = 0;
            for (let k = i * per; k < Math.min(n, (i + 1) * per); k++) {
                s += v[k];
                c++;
            }
            return c > 0 ? Math.min(1, s / c * 1.4) : 0;
        }

        ImageAnalyser {
            id: analyser

            sourceItem: pill.tracksArt && pill.kind === "media" ? mediaArt.image : null
            rescaleSize: 32
        }

        Connections {
            function onStatusChanged(): void {
                if (mediaArt.image.status === Image.Ready)
                    analyser.requestUpdate();
            }

            target: mediaArt.image
        }

        Loader {
            active: pill.eqRunning

            sourceComponent: ServiceRef {
                service: Audio.cava
            }
        }

        // Media: artwork left, live equaliser right
        Item {
            anchors.fill: parent
            visible: pill.kind === "media"

            RoundImage {
                id: mediaArt

                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                source: root.artUrl
            }

            Item {
                width: 18
                height: 14
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                EqBar {
                    idx: 0
                    color: pill.tint
                    peak: 13
                    durUp: 340
                    durDown: 380
                    level: pill.level(0)
                    live: pill.cavaLive
                    running: pill.eqRunning
                }
                EqBar {
                    idx: 1
                    color: pill.tint
                    peak: 15
                    durUp: 440
                    durDown: 410
                    level: pill.level(1)
                    live: pill.cavaLive
                    running: pill.eqRunning
                }
                EqBar {
                    idx: 2
                    color: pill.tint
                    peak: 12
                    durUp: 390
                    durDown: 430
                    level: pill.level(2)
                    live: pill.cavaLive
                    running: pill.eqRunning
                }
                EqBar {
                    idx: 3
                    color: pill.tint
                    peak: 14
                    durUp: 480
                    durDown: 450
                    level: pill.level(3)
                    live: pill.cavaLive
                    running: pill.eqRunning
                }
            }
        }

        // System activity (mute / volume / charging)
        Item {
            anchors.fill: parent
            visible: pill.kind === "hud"

            MaterialIcon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.hudIcon
                color: root.hudColor
                fontStyle: Tokens.font.icon.size(16).build()
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.hudText
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.hudColor
            }
        }

        // Timer
        Item {
            anchors.fill: parent
            visible: pill.kind === "timer"

            MaterialIcon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "timer"
                color: root.colTimer
                fontStyle: Tokens.font.icon.size(16).build()
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.timerText
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.colTimer
            }
        }

        // Notification
        Item {
            anchors.fill: parent
            visible: pill.kind === "notif"

            RoundImage {
                id: notifIcon

                anchors.left: parent.left
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                source: root.notifData.icon
                fallback: "notifications"
                fallbackColor: Qt.alpha(root.colTextPrimary, 0.6)
                fallbackSize: 13
            }

            StyledText {
                anchors.left: notifIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.notifData.summary
                textFormat: Text.PlainText
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: root.colTextPrimary
                elide: Text.ElideRight
            }
        }
    }

    // B13: Reusable pressable icon component with scale & opacity feedback
    component PressableIcon: Item {
        id: btn

        property string icon: ""
        property int pointSize: 20
        property color color: root.colTextPrimary
        property color activeColor: root.colTextPrimary

        signal clicked

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
