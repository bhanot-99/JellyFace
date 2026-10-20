pragma Singleton

import QtQuick
import Quickshell
import Jellyface.Config
import Jellyface.Services
import qs.services

// Lock, sleep, restart, shut down and log out, run exactly as Classic's session menu runs them (sleep goes through
// SleepGuard, which locks first).
Singleton {
    function run(command: list<string>): void {
        if (!SleepGuard.run(command) && !SessionManager.exec(command))
            Quickshell.execDetached(command);
    }

    function lock(): void {
        LockBridge.lockNow();
    }

    function sleep(): void {
        run(["suspend"]);
    }

    function restart(): void {
        run(GlobalConfig.session.commands.reboot);
    }

    function shutdown(): void {
        run(GlobalConfig.session.commands.shutdown);
    }

    function logout(): void {
        run(GlobalConfig.session.commands.logout);
    }
}
