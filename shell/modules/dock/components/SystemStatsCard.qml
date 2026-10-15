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

StyledRect {
    id: root

    color: Glass.enabled ? Glass.mist : Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge
    implicitHeight: 410

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
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: Tokens.rounding.medium
                color: Qt.alpha(Colours.palette.m3primary, Glass.enabled ? 0.25 : 0.15)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "monitoring"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("System Resources & Activity")
                font: Tokens.font.title.small
                color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                Layout.fillWidth: true
            }

            // Launch Cosmic System Monitor button
            StyledRect {
                implicitWidth: monText.implicitWidth + 14
                implicitHeight: 24
                radius: 12
                color: monHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh)

                Row {
                    id: monText
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "speed"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Monitor"
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
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

        // Top Row: 3 Resource Gauges (CPU, RAM, Storage/Disk Analyzer)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // 1. CPU Gauge
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 88
                radius: Tokens.rounding.large
                color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        MaterialIcon {
                            text: "developer_board"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            text: "CPU"
                            font: Tokens.font.label.small
                            color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: `${Math.round(Cpu.percentage * 100)}%`
                            font: Tokens.font.title.small
                            color: Glass.enabled ? Glass.ice : Colours.palette.m3primary
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Glass.enabled ? Glass.well : Colours.palette.m3surfaceContainerHighest

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Cpu.percentage))
                            height: parent.height
                            radius: parent.radius
                            color: Colours.palette.m3primary

                            Behavior on width {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }

                    StyledText {
                        text: Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)}°C` : "Active load"
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                    }
                }
            }

            // 2. Memory (RAM) Gauge
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 88
                radius: Tokens.rounding.large
                color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        MaterialIcon {
                            text: "memory"
                            color: Colours.palette.m3tertiary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            text: "Memory"
                            font: Tokens.font.label.small
                            color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: `${Math.round(Memory.percentage * 100)}%`
                            font: Tokens.font.title.small
                            color: Glass.enabled ? Glass.ice : Colours.palette.m3tertiary
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Glass.enabled ? Glass.well : Colours.palette.m3surfaceContainerHighest

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Memory.percentage))
                            height: parent.height
                            radius: parent.radius
                            color: Colours.palette.m3tertiary

                            Behavior on width {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }

                    StyledText {
                        text: Units.formatKibUsage(Memory.used, Memory.total)
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                    }
                }
            }

            // 3. Storage & Disk Analyzer
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 88
                radius: Tokens.rounding.large
                color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        MaterialIcon {
                            text: "hard_drive"
                            color: Colours.palette.m3secondary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            text: "Disk"
                            font: Tokens.font.label.small
                            color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: `${Math.round((Storage.primaryDisk?.perc ?? 0) * 100)}%`
                            font: Tokens.font.title.small
                            color: Glass.enabled ? Glass.ice : Colours.palette.m3secondary
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Glass.enabled ? Glass.well : Colours.palette.m3surfaceContainerHighest

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Storage.primaryDisk?.perc ?? 0))
                            height: parent.height
                            radius: parent.radius
                            color: Colours.palette.m3secondary

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
                            text: Storage.primaryDisk ? Units.formatKibUsage(Storage.primaryDisk.used, Storage.primaryDisk.total) : "No disk"
                            font: Tokens.font.label.small
                            color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                            Layout.fillWidth: true
                        }

                        // Analyze button
                        StyledRect {
                            implicitWidth: baobabLabel.implicitWidth + 8
                            implicitHeight: 18
                            radius: 9
                            color: baobabHover.hovered ? Colours.palette.m3secondaryContainer : (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest)

                            Row {
                                id: baobabLabel
                                anchors.centerIn: parent
                                spacing: 2

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "pie_chart"
                                    color: Colours.palette.m3secondary
                                    fontStyle: Tokens.font.icon.small
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Analyze"
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3secondary
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
                    }
                }
            }
        }

        // Middle Section: Live Network Usage & Graph
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 110
            radius: Tokens.rounding.large
            color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "swap_vert"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: "Live Network Throughput"
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                        Layout.fillWidth: true
                    }

                    Row {
                        spacing: 12

                        Row {
                            spacing: 4
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "download"
                                color: Colours.palette.m3tertiary
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3tertiary
                            }
                        }

                        Row {
                            spacing: 4
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "upload"
                                color: Colours.palette.m3secondary
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3secondary
                            }
                        }
                    }
                }

                // Sparkline Graph
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
                        line1Color: Colours.palette.m3secondary
                        line1FillAlpha: 0.2
                        line2: NetworkUsage.downloadBuffer
                        line2Color: Colours.palette.m3tertiary
                        line2FillAlpha: 0.25
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

                    // Fallback placeholder while collecting initial network samples
                    StyledText {
                        anchors.centerIn: parent
                        text: "Collecting network history..."
                        font: Tokens.font.body.small
                        color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                        visible: NetworkUsage.downloadBuffer.count < 2
                    }
                }
            }
        }

        // Bottom Section: Active Windows & App Activity
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 74
            radius: Tokens.rounding.large
            color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "select_window"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: "App Activity"
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: `${CosmicWindows.windows.length} open`
                        font: Tokens.font.label.small
                        color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                    }
                }

                // Horizontal scrollable window pills
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

                                delegate: StyledRect {
                                    id: winPill

                                    required property var modelData
                                    readonly property var win: modelData
                                    readonly property bool isActive: win.id === CosmicWindows.activeId

                                    implicitWidth: Math.min(180, winContent.implicitWidth + 16)
                                    implicitHeight: 28
                                    radius: 14
                                    color: winHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (isActive ? Colours.palette.m3primaryContainer : (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainer))
                                    border.width: isActive ? 1 : 0
                                    border.color: Colours.palette.m3primary

                                    RowLayout {
                                        id: winContent
                                        anchors.centerIn: parent
                                        spacing: 4

                                        MaterialIcon {
                                            text: isActive ? "radio_button_checked" : "radio_button_unchecked"
                                            color: isActive ? Colours.palette.m3primary : (Glass.enabled ? Glass.haze : Colours.palette.m3outline)
                                            fontStyle: Tokens.font.icon.small
                                        }

                                        StyledText {
                                            text: winPill.win?.title || winPill.win?.app_id || "Window"
                                            font: Tokens.font.label.small
                                            color: isActive ? Colours.palette.m3onPrimaryContainer : (Glass.enabled ? Glass.ice : Colours.palette.m3onSurface)
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 140
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

                            // Empty state when no windows are open
                            StyledText {
                                text: "No active application windows"
                                font: Tokens.font.label.small
                                color: Glass.enabled ? Glass.haze : Colours.palette.m3outline
                                visible: CosmicWindows.windows.length === 0
                            }
                        }
                    }
                }
            }
        }
    }
}
