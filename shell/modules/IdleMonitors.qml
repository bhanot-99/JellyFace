pragma ComponentBehavior: Bound

import "lock"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Jellyface.Config
import Jellyface.Services
import qs.services

Scope {
    id: root

    required property Lock lock
    readonly property bool hasPlayer: Players.list.some(p => p.isPlaying)
    readonly property bool isCharging: !UPower.onBattery
    readonly property bool enabled: {
        if (GlobalConfig.general.idle.inhibitWhenAudio && hasPlayer)
            return false;
        if (GlobalConfig.general.idle.inhibitWhenCharging && isCharging)
            return false;
        return true;
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (typeof action === "string")
            Hypr.dispatch(Hypr.usingLua && ["dpms off", "dpms on"].includes(action) ? `hl.dsp.dpms({ action = "${action === "dpms off" ? "disable" : "enable"}" })` : action);
        else if (!SessionManager.exec(action))
            Quickshell.execDetached(action);
    }

    // A sleep asked for from JellyFace (services/SleepGuard): lock first, sleep once the lock screen is up. If the lock
    // does not come up within 3 s the machine sleeps anyway (COSMIC's locker then locks): it is never kept awake.
    property var pendingSleep: null

    function sleepNow(): void {
        const command = pendingSleep;
        pendingSleep = null;
        sleepTimeout.stop();
        if (command && !SessionManager.exec(command))
            Quickshell.execDetached(command);
    }

    Connections {
        function onRequested(command: list<string>): void {
            root.pendingSleep = command;
            sleepTimeout.restart();
            if (root.lock.lock.secure)
                root.sleepNow();
            else
                root.lock.lock.locked = true;
        }

        target: SleepGuard
    }

    Connections {
        function onSecureChanged(): void {
            if (root.lock.lock.secure && root.pendingSleep)
                root.sleepNow();
        }

        target: root.lock.lock
    }

    Timer {
        id: sleepTimeout

        interval: 3000
        onTriggered: root.sleepNow()
    }

    Connections {
        function onAboutToSleep(): void {
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }

        function onLockRequested(): void {
            root.lock.lock.locked = true;
        }

        function onUnlockRequested(): void {
            root.lock.lock.unlock();
        }

        target: SessionManager
    }

    Variants {
        model: GlobalConfig.general.idle.timeouts.values

        IdleMonitor {
            required property var modelData

            enabled: {
                if (!root.enabled || !(modelData.enabled ?? true))
                    return false;
                if (modelData.inhibitWhenAudio && root.hasPlayer)
                    return false;
                if (modelData.inhibitWhenCharging && root.isCharging)
                    return false;
                return true;
            }
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
