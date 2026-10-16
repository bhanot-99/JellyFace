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
import qs.services
import qs.utils
import ".."

ModularCard {
    id: root

    cardId: "memory"
    title: Tr.tr("Memory")
    minW: 160
    minH: 140
    canResize: true
    contentPadding: 12

    readonly property bool isTelemetryActive: root.visible && (typeof dashboardWin !== "undefined" ? dashboardWin.shown : true)

    ServiceRef {
        service: root.isTelemetryActive ? Memory : null
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Header Row: Icon squircle + Title + Percentage
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
                    text: "analytics"
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Memory")
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: Glass.textPrimary
                Layout.fillWidth: true
            }

            StyledText {
                text: `${Math.round(Math.max(0, Math.min(1, Memory.percentage ?? 0)) * 100)}%`
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Glass.textPrimary
            }
        }

        // Chunky Circular Arc Gauge Pod
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
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
                        sweepAngle: Math.max(1, Math.min(360, (Memory.percentage ?? 0) * 360))
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "analytics"
                color: Glass.textPrimary
                fontStyle: Tokens.font.icon.medium
            }
        }

        // Subtitle / Memory Usage Detail Readout
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            StyledText {
                text: Units.formatKibUsage(Memory.used, Memory.total)
                font: Tokens.font.label.small
                color: Glass.textSecondary
                Layout.fillWidth: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
