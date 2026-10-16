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
// Left Column: 4 Autonomous Hardware Diagnostic Cards (CPU, Memory, Disk, Network)
// Right Column: NotificationCenter & MailFeed
Item {
    id: root

    readonly property real screenW: parent ? parent.width : 1920
    readonly property real screenH: parent ? parent.height : 1080
    readonly property real cx: Math.round(screenW / 2)
    readonly property real cy: Math.round(screenH / 2)
    readonly property real baseTop: Math.max(40, cy - 250)

    readonly property alias commandBarCard: commandBar
    readonly property alias cpuCard: cpuCard
    readonly property alias memoryCard: memoryCard
    readonly property alias diskCard: diskCard
    readonly property alias networkCard: networkCard
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

    // 2. CPU Metric Card
    CpuCard {
        id: cpuCard

        defaultX: root.cx - 520
        defaultY: root.baseTop + 64
        defaultW: 204
        defaultH: 156
        z: 5
    }

    // 3. Memory Metric Card
    MemoryCard {
        id: memoryCard

        defaultX: root.cx - 304
        defaultY: root.baseTop + 64
        defaultW: 204
        defaultH: 156
        z: 5
    }

    // 4. Disk Metric Card
    DiskCard {
        id: diskCard

        defaultX: root.cx - 88
        defaultY: root.baseTop + 64
        defaultW: 208
        defaultH: 156
        z: 5
    }

    // 5. Network Throughput & Sparkline Card
    NetworkCard {
        id: networkCard

        defaultX: root.cx - 520
        defaultY: root.baseTop + 232
        defaultW: 640
        defaultH: 252
        z: 5
    }

    // 6. NotificationCenter Module (Live Notifications Feed)
    NotificationCenter {
        id: notifCard

        defaultX: root.cx + 132
        defaultY: root.baseTop + 64
        defaultW: 388
        defaultH: 156
        z: 5
    }

    // 7. MailFeed Module (Primary Unread Mails Feed)
    MailFeed {
        id: mail

        defaultX: root.cx + 132
        defaultY: root.baseTop + 232
        defaultW: 388
        defaultH: 252
        z: 5
    }
}
