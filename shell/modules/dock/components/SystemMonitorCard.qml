pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Jellyface.Components
import Jellyface.Config
import Jellyface.I18n
import Jellyface.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import ".."

ModularCard {
    id: root

    cardId: "systemMonitor"
    title: Tr.tr("System Monitor")
    minW: 520
    minH: 340
    canResize: true
    contentPadding: 16

    readonly property bool isTelemetryActive: root.visible && (typeof dashboardWin !== "undefined" ? dashboardWin.shown : true)

    ServiceRef {
        service: root.isTelemetryActive ? Cpu : null
    }

    ServiceRef {
        service: root.isTelemetryActive ? Memory : null
    }

    ServiceRef {
        service: root.isTelemetryActive ? Storage : null
    }

    ServiceRef {
        service: root.isTelemetryActive ? NetworkUsage : null
    }

    // Reusable Tactile Skeuomorphic Circular Arc Gauge Pod (Frosted Glass Recessed Well)
    component RadialGaugePod: Rectangle {
        id: pod

        required property string title
        required property string icon
        property real value: 0 // 0.0 to 1.0
        property string detailText: ""
        property bool showAnalyze: false

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 148
        radius: Tokens.rounding.large
        color: Glass.glassRecessedWell
        border.width: 1
        border.color: Glass.glassBorder

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            // Top Header: Title + Percentage
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: pod.title
                    font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                    color: Glass.textPrimary
                    Layout.fillWidth: true
                }

                StyledText {
                    text: `${Math.round(Math.max(0, Math.min(1, pod.value)) * 100)}%`
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Glass.textPrimary
                }
            }

            // Radial Gauge with 8px Chunky Arc & Centered 18px Hardware Icon
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 64
                implicitHeight: 64

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    asynchronous: true

                    // Recessed Track Ring
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Glass.enabled ? Qt.rgba(1.0, 1.0, 1.0, 0.12) : Colours.palette.m3surfaceContainerHighest
                        strokeWidth: 8
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: 32
                            centerY: 32
                            radiusX: 26
                            radiusY: 26
                            startAngle: -90
                            sweepAngle: 360
                        }
                    }

                    // Active Arc (Chunky 8px Glass.glassActivePill with smooth stroke)
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Glass.glassActivePill
                        strokeWidth: 8
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: 32
                            centerY: 32
                            radiusX: 26
                            radiusY: 26
                            startAngle: -90
                            sweepAngle: Math.max(1, Math.min(360, pod.value * 360))
                        }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: pod.icon
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.medium
                }
            }

            // Secondary Metrics or Inset Micro-Button
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                StyledText {
                    text: pod.detailText
                    font: Tokens.font.label.small
                    color: Glass.textSecondary
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: !pod.showAnalyze
                }

                Rectangle {
                    visible: pod.showAnalyze
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: analyzeRow.implicitWidth + 14
                    implicitHeight: 22
                    radius: Tokens.rounding.full
                    color: analyzeHover.hovered ? Glass.glassPillHover : Glass.glassElevatedTile
                    border.width: 1
                    border.color: analyzeHover.hovered ? Glass.glassActivePill : Glass.glassBorder

                    Row {
                        id: analyzeRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "pie_chart"
                            color: Glass.textPrimary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tr.tr("Analyze")
                            font: Tokens.font.label.small
                            color: Glass.textPrimary
                        }
                    }

                    HoverHandler {
                        id: analyzeHover
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Card Header (Glass.frost Icon Squircle + Glass.ice Title)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: Tokens.rounding.small
                color: Glass.glassElevatedTile
                border.width: 1
                border.color: Glass.glassBorder

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "monitoring"
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Tr.tr("System Resources")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Glass.textPrimary
                }

                StyledText {
                    text: Tr.tr("Live Hardware Diagnostics")
                    font: Tokens.font.label.small
                    color: Glass.textSecondary
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // 1. Three Concentric / Circular Gauge Pods (CPU, Memory, Disk)
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // CPU Gauge Pod
            RadialGaugePod {
                title: "CPU"
                icon: "memory"
                value: Cpu.percentage ?? 0
                detailText: Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)}°C` : (Cpu.frequency > 0 ? `${(Cpu.frequency / 1000).toFixed(1)} GHz` : "Active")
            }

            // Memory (RAM) Gauge Pod
            RadialGaugePod {
                title: "Memory"
                icon: "analytics"
                value: Memory.percentage ?? 0
                detailText: Units.formatKibUsage(Memory.used, Memory.total)
            }

            // Storage (Disk) Gauge Pod with Detached Inset Micro-Button
            RadialGaugePod {
                title: "Disk"
                icon: "hard_disk"
                value: Storage.primaryDisk?.perc ?? Storage.percentage ?? 0
                detailText: Storage.primaryDisk ? Units.formatKibUsage(Storage.primaryDisk.used, Storage.primaryDisk.total) : "No disk"
                showAnalyze: true
            }
        }

        // 2. Live Network Throughput & Monochromatic Sparkline Graph
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 124
            radius: Tokens.rounding.large
            color: Glass.glassRecessedWell
            border.width: 1
            border.color: Glass.glassBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "swap_vert"
                        color: Glass.textPrimary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Tr.tr("Network Throughput")
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: Glass.textPrimary
                        Layout.fillWidth: true
                    }

                    // Monochromatic Tabular Readouts
                    Row {
                        spacing: 14

                        Row {
                            spacing: 4
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "download"
                                color: Glass.textPrimary
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true)
                                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                                color: Glass.textPrimary
                            }
                        }

                        Row {
                            spacing: 4
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "upload"
                                color: Glass.textSecondary
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true)
                                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                                color: Glass.textSecondary
                            }
                        }
                    }
                }

                // Sparkline Graph: Crisp Monochromatic Silver Curves
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
                        line1Color: Glass.textSecondary
                        line1FillAlpha: 0.10
                        line2: NetworkUsage.downloadBuffer
                        line2Color: Glass.glassActivePill
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
                        text: Tr.tr("Collecting throughput metrics...")
                        font: Tokens.font.label.small
                        color: Glass.textMuted
                        visible: NetworkUsage.downloadBuffer.count < 2
                    }
                }
            }
        }
    }
}
