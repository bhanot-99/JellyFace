pragma Singleton

import Quickshell

// The session lock (shell.qml's Lock), for interfaces that lock from a button rather than a shortcut
// (Drift's power menu and command bar), and the password check for a lock surface the lock creates by itself
// (Drift's, drift/surfaces/lock). Set by shell.qml.
Singleton {
    property var lock // WlSessionLock
    property var pam // modules/lock/Pam.qml

    function lockNow(): void {
        if (lock)
            lock.locked = true;
    }
}
