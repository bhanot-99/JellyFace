pragma Singleton

import Quickshell

// Suspend and hibernate from JellyFace's own menus and actions: lock with JellyFace's lock screen first, then sleep
// (modules/IdleMonitors.qml does both). COSMIC's own locker locks on every suspend and wins the race against a lock
// that only starts with the sleep, so waking up showed COSMIC's lock screen. The lid has the same fix: scripts/lid.sh.
Singleton {
    readonly property list<string> sleepCommands: ["suspend", "hibernate", "suspendthenhibernate"]

    signal requested(command: list<string>)

    // takes a sleep command (true) and leaves anything else to the caller (false). Spelled the ways SessionManager.exec
    // accepts: "suspend", "systemctl suspend", "suspend-then-hibernate", ...
    function run(command: list<string>): bool {
        if (command.length === 0)
            return false;
        let cmd = command[0];
        if ((cmd === "systemctl" || cmd === "loginctl") && command.length === 2)
            cmd = command[1];
        if (!sleepCommands.includes(String(cmd).replace(/[-_]/g, "").toLowerCase()))
            return false;
        requested(command);
        return true;
    }
}
