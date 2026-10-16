pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Components
import Jellyface.Config
import Jellyface.I18n
import Jellyface.Services
import qs.components
import qs.services
import qs.utils
import ".."

ModularCard {
    id: root

    cardId: "network"
    title: Tr.tr("Network")
    minW: 320
    minH: 160
    canResize: true
    contentPadding: 14

    readonly property bool isTelemetryActive: root.visible && (typeof dashboardWin !== "undefined" ? dashboardWin.shown : true)

    ServiceRef {
        service: root.isTelemetryActive ? NetworkUsage : null
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Header Row: Icon + Title + Real-time Download/Upload Speed Readouts
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: Tokens.rounding.small
                color: Glass.glassElevatedTile
                border.width: 0

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "swap_vert"
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Network Throughput")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Glass.textPrimary
                Layout.fillWidth: true
            }

            // Tabular Readouts (Download & Upload)
            Row {
                spacing: 12

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

        // Live Sparkline Graph: Monochromatic silver/accent curves
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
