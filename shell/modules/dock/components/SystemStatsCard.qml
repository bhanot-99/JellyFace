pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Components
import Jellyface.Config
import Jellyface.I18n
import Jellyface.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Rectangle {
    id: root

    color: Qt.rgba(1, 1, 1, 0.04)
    radius: 16
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.06)

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    ServiceRef {
        service: NetworkUsage
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Card Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 6
                color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.15) // Sky blue

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "monitoring"
                    color: "#38bdf8"
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("System Resources & Activity")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Qt.rgba(1, 1, 1, 0.95)
                Layout.fillWidth: true
            }

            // Launch Cosmic System Monitor button
            Rectangle {
                implicitWidth: monText.implicitWidth + 12
                implicitHeight: 24
                radius: 6
                color: monHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)

                Row {
                    id: monText
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "speed"
                        color: Qt.rgba(1, 1, 1, 0.85)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Monitor"
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }
                }

                HoverHandler {
                    id: monHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", "com.system76.CosmicMonitor"])
                }
            }
        }

        // Top Row: Strict 3-Column Equal-Width Grid for CPU, RAM, and Disk
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // 1. CPU Metric Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 76
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: "CPU"
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.55)
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: `${Math.round(Cpu.percentage * 100)}%`
                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            color: "#38bdf8"
                        }
                    }

                    // Low-profile 3.5px meter with subtle glow
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 3.5
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Cpu.percentage))
                            height: parent.height
                            radius: parent.radius
                            color: "#38bdf8"

                            Behavior on width {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)}°C` : "Active load"
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.45)
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // 2. Memory (RAM) Metric Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 76
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: "Memory"
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.55)
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: `${Math.round(Memory.percentage * 100)}%`
                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            color: "#a855f7"
                        }
                    }

                    // Low-profile 3.5px meter with subtle glow
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 3.5
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Memory.percentage))
                            height: parent.height
                            radius: parent.radius
                            color: "#a855f7"

                            Behavior on width {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: Units.formatKibUsage(Memory.used, Memory.total)
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.45)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // 3. Storage (Disk) Metric Card - Zero Collision Layout
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 76
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: "Disk"
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.55)
                        }

                        // Analyze pill cleanly docked in header row to avoid collision
                        Rectangle {
                            implicitWidth: baobabLabel.implicitWidth + 8
                            implicitHeight: 16
                            radius: 4
                            color: baobabHover.hovered ? Qt.rgba(251 / 255, 146 / 255, 60 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                id: baobabLabel
                                anchors.centerIn: parent
                                spacing: 2

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "pie_chart"
                                    color: "#fb923c"
                                    fontStyle: Tokens.font.icon.small
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Analyze"
                                    font: Tokens.font.label.small
                                    color: "#fb923c"
                                }
                            }

                            HoverHandler {
                                id: baobabHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["distrobox-host-exec", "gtk-launch", "org.gnome.baobab"])
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: `${Math.round((Storage.primaryDisk?.perc ?? 0) * 100)}%`
                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            color: "#fb923c"
                        }
                    }

                    // Low-profile 3.5px meter with subtle glow
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 3.5
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Storage.primaryDisk?.perc ?? 0))
                            height: parent.height
                            radius: parent.radius
                            color: "#fb923c"

                            Behavior on width {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: Storage.primaryDisk ? Units.formatKibUsage(Storage.primaryDisk.used, Storage.primaryDisk.total) : "No disk detected"
                            font: Tokens.font.label.small
                            color: Qt.rgba(1, 1, 1, 0.45)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Middle Section: Live Network Throughput & Sparkline Graph
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.05)
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "swap_vert"
                        color: "#38bdf8"
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: "Network Throughput"
                        font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                        color: Qt.rgba(1, 1, 1, 0.90)
                        Layout.fillWidth: true
                    }

                    // Tabular figure readout to prevent jitter
                    Row {
                        spacing: 12

                        Row {
                            spacing: 4
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "download"
                                color: "#38bdf8"
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true)
                                font: Tokens.font.label.small
                                color: "#38bdf8"
                            }
                        }

                        Row {
                            spacing: 4
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "upload"
                                color: "#a855f7"
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true)
                                font: Tokens.font.label.small
                                color: "#a855f7"
                            }
                        }
                    }
                }

                // Sparkline Graph with clean clipping
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    SparklineItem {
                        id: sparkline

                        property real targetMax: 1024
                        property real smoothMax: targetMax

                        anchors.fill: parent
                        line1: NetworkUsage.uploadBuffer
                        line1Color: "#a855f7"
                        line1FillAlpha: 0.15
                        line2: NetworkUsage.downloadBuffer
                        line2Color: "#38bdf8"
                        line2FillAlpha: 0.20
                        maxValue: smoothMax
                        historyLength: NetworkUsage.historyLength

                        Connections {
                            function onValuesChanged(): void {
                                sparkline.targetMax = Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024);
                                slideAnim.restart();
                            }

                            target: NetworkUsage.downloadBuffer
                        }

                        NumberAnimation {
                            id: slideAnim
                            target: sparkline
                            property: "slideProgress"
                            from: 0
                            to: 1
                            easing.type: Easing.Linear
                            duration: 1000
                        }

                        Behavior on smoothMax {
                            Anim {}
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: "Collecting throughput metrics..."
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.40)
                        visible: NetworkUsage.downloadBuffer.count < 2
                    }
                }
            }
        }

        // Bottom Section: App Activity Task Strip with Smart Truncate
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.05)
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                RowLayout {
                    spacing: 4

                    MaterialIcon {
                        text: "select_window"
                        color: Qt.rgba(1, 1, 1, 0.70)
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: "Active"
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.50)
                    }
                }

                // Window pills with smart truncate
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        anchors.fill: parent
                        contentWidth: windowPills.implicitWidth
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: windowPills
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Repeater {
                                model: CosmicWindows.windows

                                delegate: Rectangle {
                                    id: winPill

                                    required property var modelData
                                    readonly property var win: modelData
                                    readonly property bool isActive: win.id === CosmicWindows.activeId

                                    implicitWidth: Math.min(160, winContent.implicitWidth + 14)
                                    implicitHeight: 26
                                    radius: 6
                                    color: winHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : (isActive ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18) : Qt.rgba(1, 1, 1, 0.05))
                                    border.width: 1
                                    border.color: isActive ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.06)

                                    RowLayout {
                                        id: winContent
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Rectangle {
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: isActive ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.35)
                                        }

                                        StyledText {
                                            text: winPill.win?.title || winPill.win?.app_id || "Window"
                                            font: Tokens.font.label.small
                                            color: isActive ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.70)
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 125
                                        }
                                    }

                                    HoverHandler {
                                        id: winHover
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: CosmicWindows.activate(winPill.win.id)
                                    }
                                }
                            }

                            StyledText {
                                text: "No active application windows"
                                font: Tokens.font.label.small
                                color: Qt.rgba(1, 1, 1, 0.35)
                                visible: CosmicWindows.windows.length === 0
                            }
                        }
                    }
                }
            }
        }
    }
}
