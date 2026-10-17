import QtQuick
import Quickshell
import Quickshell.Io
import Jellyface
import qs.components.misc
import qs.services
import qs.modules.nexus

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: CosmicWindows.fullscreen

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "nexus"
        description: "Open nexus"
        onPressed: WindowFactory.create()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle launcher, dashboard and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = ShellState.forActive();
            v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.dashboard = !screenState.dashboard;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.session = !screenState.session;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const screenState = ShellState.forActive();
                screenState.launcher = !screenState.launcher;
            }
            root.launcherInterrupted = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.sidebar = !screenState.sidebar;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.utilities = !screenState.utilities;
        }
    }

    Timer {
        id: popAllTimer
        interval: 5000
        repeat: false
        onTriggered: {
            drawersHandler.closeAll();
        }
    }

    Timer {
        id: popoutCycleTimer
        property var cycleItems: ["network", "bluetooth", "battery"]
        property int cycleIndex: 0
        interval: 1600
        repeat: true
        onTriggered: {
            cycleIndex = (cycleIndex + 1) % cycleItems.length;
            drawersHandler.popout(cycleItems[cycleIndex]);
        }
    }

    IpcHandler {
        id: drawersHandler

        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const screenState = ShellState.forActive();
                screenState[drawer] = !screenState[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function open(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const screenState = ShellState.forActive();
                screenState[drawer] = true;
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function close(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                const screenState = ShellState.forActive();
                screenState[drawer] = false;
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function openAll(): void {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            if (screenState) {
                screenState.launcher = true;
                screenState.dashboard = true;
                screenState.osd = true;
                screenState.sidebar = true;
                screenState.utilities = true;
            }
        }

        function closeAll(): void {
            popAllTimer.stop();
            popoutCycleTimer.stop();
            const screenState = ShellState.forActive();
            if (screenState) {
                screenState.launcher = false;
                screenState.dashboard = false;
                screenState.osd = false;
                screenState.sidebar = false;
                screenState.utilities = false;
            }
            const comps = ShellState.componentsForActive();
            if (comps && comps.panels && comps.panels.popouts) {
                comps.panels.popouts.hasCurrent = false;
            }
        }

        function popout(name: string): void {
            const comps = ShellState.componentsForActive();
            if (comps && comps.panels && comps.panels.popouts) {
                if (!name || name === "close") {
                    comps.panels.popouts.hasCurrent = false;
                    return;
                }
                const popName = (name === "wifi") ? "network" : name;
                comps.panels.popouts.currentName = popName;
                comps.panels.popouts.currentCenter = comps.panels.height / 2;
                comps.panels.popouts.hasCurrent = true;
            }
        }

        function popAll(seconds: int): void {
            if (root.hasFullscreen)
                return;
            openAll();
            popout("network");
            popoutCycleTimer.cycleIndex = 0;
            popoutCycleTimer.restart();

            const sec = seconds > 0 ? seconds : 5;
            popAllTimer.interval = sec * 1000;
            popAllTimer.restart();
        }

        // Open the dashboard on a given tab: 0 Dashboard, 1 Media, 2 Performance, 3 Weather
        function dashboardTab(index: int): void {
            const screenState = ShellState.forActive();
            screenState.dashboardTab = index;
            screenState.dashboard = true;
        }

        function list(): string {
            const screenState = ShellState.forActive();
            return Object.keys(screenState).filter(k => typeof screenState[k] === "boolean").join("\n");
        }

        function isOpen(drawer: string): string {
            const screenState = ShellState.forActive();
            if (typeof screenState[drawer] !== "boolean")
                return "unknown";
            return screenState[drawer] ? "1" : "0";
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        target: "nexus"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "jellyface.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}
