pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery and power profile for Control Center. The profile is Pop!_OS's system76-power (Battery / Balanced /
// Performance), run on the host. The battery graph is sampled here every five minutes (the last 12 hours), since
// UPower's own history is not exposed to the shell.
Singleton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool present: battery?.isLaptopBattery ?? false
    readonly property real percent: battery?.percentage ?? 0
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.PendingCharge].includes(battery?.state)
    readonly property bool full: battery?.state === UPowerDeviceState.FullyCharged
    readonly property string timeText: {
        const secs = charging ? battery?.timeToFull : battery?.timeToEmpty;
        if (full)
            return "Fully charged";
        if (!secs || secs <= 0)
            return charging ? "Charging" : "On battery";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return `${charging ? "Full in" : "About"} ${h > 0 ? `${h} h ` : ""}${m} min${charging ? "" : " left"}`;
    }

    property string profile: "" // battery | balanced | performance
    property var history: [] // percent, oldest first

    function setProfile(p: string): void {
        profile = p;
        Quickshell.execDetached(["distrobox-host-exec", "system76-power", "profile", p]);
        refresh.restart();
    }

    Process {
        id: query

        command: ["distrobox-host-exec", "system76-power", "profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Power Profile:\s*(\w+)/);
                if (m)
                    root.profile = m[1].toLowerCase();
            }
        }
    }

    Timer {
        id: refresh

        interval: 1500
        onTriggered: query.running = true
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 5 * 60 * 1000
        onTriggered: {
            if (root.present)
                root.history = root.history.concat([root.percent]).slice(-144);
            query.running = true;
        }
    }
}
