pragma Singleton

import Quickshell

// The session lock (shell.qml's Lock), for interfaces that lock from a button rather than a shortcut
// (Drift's power menu and command bar). Set by shell.qml.
Singleton {
    property var lock // WlSessionLock

    function lockNow(): void {
        if (lock)
            lock.locked = true;
    }
}
