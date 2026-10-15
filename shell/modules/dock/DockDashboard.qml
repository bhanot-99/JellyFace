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
// 2-column asymmetric grid hosting autonomous floating modular cards:
// Top: CommandBar (Workspace info, Brave Search, Lock toggle, Clock)
// Left: SystemMonitorCard (CPU, Memory, Disk meters, Network sparkline)
// Right: NotificationCenter & MailFeed
Item {
    id: root

    readonly property real screenW: parent ? parent.width : 1920
    readonly property real screenH: parent ? parent.height : 1080
    readonly property real cx: Math.round(screenW / 2)
    readonly property real cy: Math.round(screenH / 2)
    readonly property real baseTop: Math.max(40, cy - 250)

    readonly property alias commandBarCard: commandBar
    readonly property alias systemMonitorCard: systemMonitor
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

    // 2. SystemMonitorCard Module (CPU, Memory, Disk, Sparkline)
    SystemMonitorCard {
        id: systemMonitor

        defaultX: root.cx - 520
        defaultY: root.baseTop + 64
        defaultW: 640
        defaultH: 420
        z: 5
    }

    // 3. NotificationCenter Module (Live Notifications Feed)
    NotificationCenter {
        id: notifCard

        defaultX: root.cx + 132
        defaultY: root.baseTop + 64
        defaultW: 388
        defaultH: 136
        z: 5
    }

    // 4. MailFeed Module (Primary Mails Feed & Client Launchers)
    MailFeed {
        id: mail

        defaultX: root.cx + 132
        defaultY: root.baseTop + 212
        defaultW: 388
        defaultH: 272
        z: 5
    }
}
