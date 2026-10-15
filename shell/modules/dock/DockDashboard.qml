pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils
import "components"

// Decoupled Desktop Widget Ecosystem Canvas:
// Master outer container eliminated. Acts as an unconstrained transparent desktop canvas
// hosting 7 autonomous floating modular cards with freeform drag/drop, interactive resizing,
// coordinate persistence, and global edit/lock mode.
Item {
    id: root

    required property var dock

    readonly property real screenW: parent ? parent.width : 1920
    readonly property real screenH: parent ? parent.height : 1080
    readonly property real cx: Math.round(screenW / 2)
    readonly property real cy: Math.round(screenH / 2)
    readonly property real baseTop: Math.max(40, cy - 340)

    readonly property alias commandBarCard: commandBar
    readonly property alias appTrayCard: appTray
    readonly property alias profileCard: profile
    readonly property alias systemMonitorCard: systemMonitor
    readonly property alias activeTasksCard: activeTasks
    readonly property alias notifCard: notifCard
    readonly property alias mailCard: mail

    anchors.fill: parent

    // 1. TopCommandBar Module
    TopCommandBar {
        id: commandBar

        defaultX: root.cx - 520
        defaultY: root.baseTop
        defaultW: 1040
        defaultH: 52
        z: 10
    }

    // 2. AppLauncherTray Module (Work & Dev / AI & Web / Media & Tools)
    AppLauncherTray {
        id: appTray

        dock: root.dock
        defaultX: root.cx - 520
        defaultY: root.baseTop + 64
        defaultW: 640
        defaultH: 108
        z: 5
    }

    // 3. SystemMonitorCard Module (CPU, Memory, Disk, Sparkline)
    SystemMonitorCard {
        id: systemMonitor

        defaultX: root.cx - 520
        defaultY: root.baseTop + 184
        defaultW: 640
        defaultH: 340
        z: 5
    }

    // 4. ActiveTasksCard Module (Open Windows Taskbar)
    ActiveTasksCard {
        id: activeTasks

        defaultX: root.cx - 520
        defaultY: root.baseTop + 536
        defaultW: 640
        defaultH: 54
        z: 5
    }

    // 5. ProfileStatusCard Module (Avatar, Host, Distro, Uptime)
    ProfileStatusCard {
        id: profile

        defaultX: root.cx + 132
        defaultY: root.baseTop + 64
        defaultW: 388
        defaultH: 88
        z: 5
    }

    // 6. NotificationCenter Module (Live Notifications Feed)
    NotificationCenter {
        id: notifCard

        defaultX: root.cx + 132
        defaultY: root.baseTop + 164
        defaultW: 388
        defaultH: 136
        z: 5
    }

    // 7. MailFeed Module (Primary Mails Feed & Client Launchers)
    MailFeed {
        id: mail

        defaultX: root.cx + 132
        defaultY: root.baseTop + 312
        defaultW: 388
        defaultH: 278
        z: 5
    }
}
