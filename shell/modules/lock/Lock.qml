pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.misc

Scope {
    id: root

    property alias lock: lock
    property alias pam: pam

    // Drift draws its own lock screen (drift/surfaces/DriftLockSurface.qml): only the picture differs, the lock, its
    // safety flag and the password check below are the same. If Drift's surface ever fails to load, Classic's is used.
    readonly property Component driftSurface: Quickshell.env("JF_UI") === "drift" ? Qt.createComponent(Qt.resolvedUrl("../../drift/surfaces/DriftLockSurface.qml")) : null

    WlSessionLock {
        id: lock

        signal unlock

        surface: root.driftSurface?.status === Component.Ready ? root.driftSurface : classicSurface
    }

    Component.onCompleted: {
        if (driftSurface && driftSurface.status !== Component.Ready)
            console.warn(`drift: failed to load the lock surface, using Classic's: ${driftSurface.errorString()}`);
    }

    Component {
        id: classicSurface

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    // The surface lets the session go at the end of its unlock animation. Should it ever fail to (a surface that broke),
    // a correct password must still open the session: after 1.5 s this does it instead.
    Connections {
        function onUnlock(): void {
            unlockWatchdog.restart();
        }

        target: lock
    }

    Timer {
        id: unlockWatchdog

        interval: 1500
        onTriggered: {
            if (lock.locked) {
                console.warn("lock: the lock surface did not finish unlocking; unlocking directly");
                lock.locked = false;
            }
        }
    }

    // While locked, keep a flag file for the supervisor (scripts/lib.sh lock_handover): if this shell ever dies while
    // holding the session lock, COSMIC's own lock screen takes over instead of leaving a locked screen with no way in.
    // The state is read a moment after the change: Quickshell announces an unlock before `locked` reads false.
    Connections {
        function onLockedChanged(): void {
            flagSync.restart();
        }

        function onSecureChanged(): void {
            flagSync.restart();
        }

        target: lock
    }

    Timer {
        id: flagSync

        interval: 100
        running: true // once at start: a fresh shell is not locked, so a flag left by an earlier one is cleared
        onTriggered: {
            const flag = `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/jellyface-locked`;
            Quickshell.execDetached(lock.locked ? ["touch", flag] : ["rm", "-f", flag]);
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    Loader {
        asynchronous: true
        active: true
        onLoaded: active = false

        // Force a load of a screencopy so the one in the lock works
        // My guess is the ICC backend loads async on first request, which if the lock is
        // the first request it fails to capture (because it's async and the compositor
        // refuses capture when locked)
        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "lock"
        description: "Lock the current session"
        onPressed: lock.locked = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        function lock(): void {
            lock.locked = true;
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        // true once the compositor has confirmed the lock and the lock screen is up (scripts/lid.sh waits for this)
        function isSecure(): bool {
            return lock.secure;
        }

        target: "lock"
    }
}
