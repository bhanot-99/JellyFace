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

    // Reusable Tactile Skeuomorphic Circular Arc Gauge Component
    component RadialGaugePod: Rectangle {
        id: pod

        required property string title
        required property string icon
        property real value: 0 // 0.0 to 1.0
        property string detailText: ""
        property bool showAnalyze: false

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 146
        radius: 16
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#2e3137"
            }
            GradientStop {
                position: 1.0
                color: "#222428"
            }
        }
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.06)

        // Top specular hairline
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(255, 255, 255, 0.14)
        }

        // Bottom shadow hairline
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(0, 0, 0, 0.40)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            // Top Header: Title + Percentage
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: pod.title
                    font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                    color: "#FFFFFF"
                    Layout.fillWidth: true
                }

                StyledText {
                    text: `${Math.round(Math.max(0, Math.min(1, pod.value)) * 100)}%`
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: "#FFFFFF"
                }
            }

            // Radial Gauge with Centered Hardware Icon
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 62
                implicitHeight: 62

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    asynchronous: true

                    // Recessed Dark Charcoal Track Ring
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(255, 255, 255, 0.08)
                        strokeWidth: 5
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: 31
                            centerY: 31
                            radiusX: 27
                            radiusY: 27
                            startAngle: -90
                            sweepAngle: 360
                        }
                    }

                    // Active Arc (Solid Pure White Highlight)
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "#FFFFFF"
                        strokeWidth: 5
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: 31
                            centerY: 31
                            radiusX: 27
                            radiusY: 27
                            startAngle: -90
                            sweepAngle: Math.max(1, Math.min(360, pod.value * 360))
                        }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: pod.icon
                    color: "#FFFFFF"
                    fontStyle: Tokens.font.icon.small
                }
            }

            // Secondary Metrics or Inset Micro-Button
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                StyledText {
                    text: pod.detailText
                    font: Tokens.font.label.small
                    color: "#9CA3AF"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: !pod.showAnalyze
                }

                Rectangle {
                    visible: pod.showAnalyze
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: analyzeRow.implicitWidth + 14
                    implicitHeight: 20
                    radius: 9999
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#1b1c20"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#24262b"
                        }
                    }
                    border.width: 1
                    border.color: analyzeHover.hovered ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.08)

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.50)
                    }

                    Row {
                        id: analyzeRow
                        anchors.centerIn: parent
                        spacing: 3

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "pie_chart"
                            color: "#E5E7EB"
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tr.tr("Analyze")
                            font: Tokens.font.label.small
                            color: "#E5E7EB"
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

        // Card Header (Tactile Slate-Titanium)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 8
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#444852"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#31343b"
                    }
                }
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.12)

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.25)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "monitoring"
                    color: "#FFFFFF"
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Tr.tr("System Resources")
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: "#FFFFFF"
                }

                StyledText {
                    text: Tr.tr("Live Hardware Diagnostics")
                    font: Tokens.font.label.small
                    color: "#9CA3AF"
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
                icon: "hard_drive"
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
            radius: 16
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "#24262a"
                }
                GradientStop {
                    position: 1.0
                    color: "#1c1e22"
                }
            }
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.06)
            clip: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.radius
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(255, 255, 255, 0.12)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "swap_vert"
                        color: "#FFFFFF"
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Tr.tr("Network Throughput")
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: "#FFFFFF"
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
                                color: "#FFFFFF"
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true)
                                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                                color: "#FFFFFF"
                            }
                        }

                        Row {
                            spacing: 4
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "upload"
                                color: "#9CA3AF"
                                fontStyle: Tokens.font.icon.small
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true)
                                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                                color: "#9CA3AF"
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
                        line1Color: "#9CA3AF"
                        line1FillAlpha: 0.08
                        line2: NetworkUsage.downloadBuffer
                        line2Color: "#FFFFFF"
                        line2FillAlpha: 0.16
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
                        color: "#71717A"
                        visible: NetworkUsage.downloadBuffer.count < 2
                    }
                }
            }
        }
    }
}
