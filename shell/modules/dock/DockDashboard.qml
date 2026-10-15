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
// hosting 8 autonomous floating modular cards with freeform drag/drop, interactive resizing,
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
    readonly property alias workDevCard: workDev
    readonly property alias aiWebCard: aiWeb
    readonly property alias mediaToolsCard: mediaTools
    readonly property alias profileCard: profile
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

    // 2. WorkDevCard Module (Independent Floating Card)
    WorkDevCard {
        id: workDev

        dock: root.dock
        defaultX: root.cx - 520
        defaultY: root.baseTop + 64
        defaultW: 206
        defaultH: 108
        z: 5
    }

    // 3. AiWebCard Module (Independent Floating Card)
    AiWebCard {
        id: aiWeb

        dock: root.dock
        defaultX: root.cx - 520 + 217
        defaultY: root.baseTop + 64
        defaultW: 206
        defaultH: 108
        z: 5
    }

    // 4. MediaToolsCard Module (Independent Floating Card)
    MediaToolsCard {
        id: mediaTools

        dock: root.dock
        defaultX: root.cx - 520 + 434
        defaultY: root.baseTop + 64
        defaultW: 206
        defaultH: 108
        z: 5
    }

    // 5. SystemMonitorCard Module (CPU, Memory, Disk, Sparkline)
    SystemMonitorCard {
        id: systemMonitor

        defaultX: root.cx - 520
        defaultY: root.baseTop + 184
        defaultW: 640
        defaultH: 340
        z: 5
    }

    // 6. ProfileStatusCard Module (Avatar, Host, Distro, Uptime)
    ProfileStatusCard {
        id: profile

        defaultX: root.cx + 132
        defaultY: root.baseTop + 64
        defaultW: 388
        defaultH: 88
        z: 5
    }

    // 7. NotificationCenter Module (Live Notifications Feed)
    NotificationCenter {
        id: notifCard

        defaultX: root.cx + 132
        defaultY: root.baseTop + 164
        defaultW: 388
        defaultH: 136
        z: 5
    }

    // 8. MailFeed Module (Primary Mails Feed & Client Launchers)
    MailFeed {
        id: mail

        defaultX: root.cx + 132
        defaultY: root.baseTop + 312
        defaultW: 388
        defaultH: 278
        z: 5
    }
}
