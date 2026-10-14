pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

StyledRect {
    id: root

    required property var props
    required property ScreenState screenState
    readonly property real nonAnimHeight: btnLayout.implicitHeight + recordingList.implicitHeight + layout.spacing + layout.anchors.margins * 2

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    Ref {
        service: Recorder
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            id: btnLayout

            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: {
                    const h = icon.implicitHeight + Tokens.padding.small * 2;
                    return h - (h % 2);
                }

                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: "screen_record"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Screen recorder")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Records with Kooha")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            TextButton {
                text: Tr.tr("Open Kooha")
                onClicked: Recorder.openKooha()
            }
        }

        RecordingList {
            id: recordingList

            Layout.fillWidth: true
            props: root.props
            screenState: root.screenState
        }
    }
}
