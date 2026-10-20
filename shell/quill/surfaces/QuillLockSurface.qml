pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import qs.services
import qs.quill

// Quill's lock screen: Classic's lock screen layout in Quill's glass. Only the picture is Quill's: the session lock, its
// safety net and the password check are Classic's (modules/lock: Lock.qml creates this surface and LockBridge hands it
// the lock and the PAM check).
//   left    the weather, the system (jellyfacefetch), your agenda
//   centre  a big clock, the date, your picture (~/.face), the password, what went wrong
//   right   CPU, memory and storage, the notifications that came in, battery and power profile
//   corner  what is playing, in its own section nested into the card's bottom-right corner
// Typing goes straight into the password; Enter checks it; a wrong one shakes it.
WlSessionLockSurface {
    id: root

    readonly property var lock: LockBridge.lock
    readonly property var pam: LockBridge.pam
    property real shown: 0
    property bool leaving

    color: "black"

    Component.onCompleted: shown = 1

    Behavior on shown {
        NumberAnimation {
            duration: root.leaving ? 420 : 650
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.leaving ? Theme.curveIn : Theme.curve
        }
    }

    // unlocking: fade the lock screen away, then let the session go
    Connections {
        function onUnlock(): void {
            root.leaving = true;
            root.shown = 0;
            release.start();
        }

        target: root.lock
    }

    Timer {
        id: release

        interval: 440
        onTriggered: {
            if (root.lock)
                root.lock.locked = false;
        }
    }

    Connections {
        function onFlashMsg(): void {
            picture.shakePassword();
        }

        target: root.pam
    }

    LockScreen {
        id: picture

        anchors.fill: parent
        shown: root.shown
        focus: true

        Keys.onPressed: e => root.pam?.handleKey(e)
    }
}
