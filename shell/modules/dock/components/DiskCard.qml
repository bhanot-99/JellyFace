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

    cardId: "disk"
    title: Tr.tr("Disk")
    minW: 180
    minH: 140
    canResize: true
    contentPadding: 12

    readonly property bool isTelemetryActive: root.visible && (typeof dashboardWin !== "undefined" ? dashboardWin.shown : true)

    ServiceRef {
        service: root.isTelemetryActive ? Storage : null
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
                    text: "hard_disk"
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: Tr.tr("Disk")
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: Glass.textPrimary
                Layout.fillWidth: true
            }

            StyledText {
                text: `${Math.round(Math.max(0, Math.min(1, Storage.primaryDisk?.perc ?? Storage.percentage ?? 0)) * 100)}%`
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
                        sweepAngle: Math.max(1, Math.min(360, (Storage.primaryDisk?.perc ?? Storage.percentage ?? 0) * 360))
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "hard_disk"
                color: Glass.textPrimary
                fontStyle: Tokens.font.icon.medium
            }
        }

        // Subtitle / Detail Readout + Tactile Analyze Micro-Button
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Layout.alignment: Qt.AlignHCenter

            StyledText {
                text: Storage.primaryDisk ? Units.formatKibUsage(Storage.primaryDisk.used, Storage.primaryDisk.total) : "No disk"
                font: Tokens.font.label.small
                color: Glass.textSecondary
                Layout.fillWidth: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: analyzeRow.implicitWidth + 12
                implicitHeight: 22
                radius: Tokens.rounding.full
                color: analyzeHover.hovered ? Glass.glassPillHover : Glass.glassElevatedTile
                border.width: 0

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
