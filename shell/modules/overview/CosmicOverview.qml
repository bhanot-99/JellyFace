pragma ComponentBehavior: Bound

import "../lock"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Jellyface.Config
import qs.components
import qs.components.containers
import qs.services

// Three-finger swipes for COSMIC's own workspace overview (the one Super+W opens).
// Up: the desktop follows the fingers - it dims, shrinks and lifts off - and on release (far or fast enough) COSMIC's
// overview opens while the transition fades into it; a short or slow swipe springs back. Down: hides the overview.
// COSMIC's overview cannot be driven frame by frame, so the moving part is JellyFace's own: a still capture of the
// screen taken when the fingers touch. The overlay never takes clicks or keys.
Scope {
    id: root

    required property Lock lock

    property bool overviewOpen      // from COSMIC's own Shown/Hidden signals
    property bool tracking          // fingers down, transition following them
    property real progress          // 0 = desktop, 1 = fully zoomed out
    property real fade: 1           // hand-off to COSMIC's overview
    property var samples: []        // recent [time ms, travel mm] for the release speed
    property bool handingOff        // released far enough: waiting for COSMIC's overview to appear
    readonly property bool showing: tracking || handingOff || progressAnim.running || fadeAnim.running || progress > 0

    readonly property real travelMm: 28 // finger travel for the full transition (short: a flick of the fingers)

    function call(method: string): void {
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "com.system76.CosmicWorkspaces", "--object-path", "/com/system76/CosmicWorkspaces", "--method", `com.system76.CosmicWorkspaces.${method}`]);
    }

    function settle(to: real): void {
        tracking = false;
        progressAnim.to = to;
        progressAnim.restart();
    }

    Connections {
        target: Gestures

        function onBegan(fingers: int): void {
            if (fingers !== 3 || root.overviewOpen || root.lock.lock.locked || root.showing)
                return;
            root.samples = [];
            root.fade = 1;
            root.progress = 0;
            root.tracking = true;
        }

        function onMoved(fingers: int, dx: real, dy: real): void {
            if (!root.tracking)
                return;
            if (Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy) * 1.5) {
                root.settle(0); // a sideways swipe: not ours
                return;
            }
            const up = Math.max(0, -dy);
            // past the end it still gives a little, like a rubber band
            const p = up / root.travelMm;
            root.progress = p <= 1 ? p : 1 + (1 - 1 / (1 + (p - 1) * 2)) * 0.08;
            const now = Date.now();
            root.samples = root.samples.filter(s => now - s[0] < 100).concat([[now, up]]);
        }

        function onEnded(fingers: int, dx: real, dy: real): void {
            if (!root.tracking)
                return;
            const s = root.samples;
            const speed = s.length > 1 ? (s[s.length - 1][1] - s[0][1]) / Math.max(1, s[s.length - 1][0] - s[0][0]) * 1000 : 0; // mm/s, up > 0
            if (root.progress > 0.25 || (speed > 80 && root.progress > 0.05)) {
                root.tracking = false;
                root.handingOff = true;
                root.call("Show");
                commitAnim.restart();
                handoffTimer.restart();
            } else {
                root.settle(0);
            }
        }

        function onCancelled(fingers: int): void {
            if (root.tracking)
                root.settle(0);
        }

        function onSwiped(fingers: int, direction: string): void {
            if (fingers === 3 && direction === "down" && root.overviewOpen)
                root.call("Hide");
        }
    }

    Connections {
        target: root.lock.lock

        function onLockedChanged(): void {
            if (root.lock.lock.locked) {
                handoffTimer.stop();
                root.handingOff = false;
                root.settle(0);
            }
        }
    }

    // COSMIC's overview announces itself: fade our transition out once it is there (or after a moment regardless)
    Process {
        id: monitor

        running: true
        command: ["gdbus", "monitor", "--session", "--dest", "com.system76.CosmicWorkspaces"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("CosmicWorkspaces.Shown")) {
                    root.overviewOpen = true;
                    if (root.handingOff) {
                        handoffTimer.stop();
                        fadeAnim.restart();
                    }
                } else if (line.includes("CosmicWorkspaces.Hidden")) {
                    root.overviewOpen = false;
                }
            }
        }
        onExited: restartMonitor.start()
    }

    Timer {
        id: restartMonitor

        interval: 3000
        onTriggered: monitor.running = true
    }

    NumberAnimation {
        id: progressAnim

        target: root
        property: "progress"
        duration: Tokens.anim.durations.normal
        easing.type: Easing.OutCubic
    }

    // committed: finish the zoom-out; fadeAnim starts when COSMIC's overview says it is shown
    NumberAnimation {
        id: commitAnim

        target: root
        property: "progress"
        to: 1
        duration: 140
        easing.type: Easing.OutCubic
    }

    Timer {
        id: handoffTimer

        interval: 600 // in case the Shown signal never comes
        onTriggered: fadeAnim.restart()
    }

    SequentialAnimation {
        id: fadeAnim

        NumberAnimation {
            target: root
            property: "fade"
            to: 0
            duration: 220
            easing.type: Easing.InOutQuad
        }
        ScriptAction {
            script: {
                commitAnim.stop();
                root.handingOff = false;
                root.progress = 0;
                root.fade = 1;
            }
        }
    }

    LazyLoader {
        active: root.showing

        StyledWindow {
            id: win

            screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
            name: "overview-transition"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Item {
                readonly property real p: Math.max(0, root.progress)

                anchors.fill: parent
                opacity: root.fade

                // behind the shrinking desktop: dark, like COSMIC's overview
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: shot.hasContent ? Math.min(1, parent.p * 3) * 0.9 : parent.p * 0.45
                }

                Item {
                    id: frame

                    anchors.fill: parent
                    visible: shot.hasContent
                    scale: 1 - 0.2 * parent.p
                    transform: Translate {
                        y: -win.height * 0.04 * Math.min(1, frame.parent.p)
                    }

                    StyledClippingRect {
                        anchors.fill: parent
                        radius: 36 * Math.min(1, frame.parent.p)
                        color: "transparent"

                        ScreencopyView {
                            id: shot

                            anchors.fill: parent
                            captureSource: win.screen
                        }
                    }
                }
            }
        }
    }
}
