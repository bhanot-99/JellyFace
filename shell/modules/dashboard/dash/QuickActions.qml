pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services

// A row of one-tap actions: screenshot, screen recorder, clipboard history, focus mode, keep awake.
RowLayout {
    id: root

    required property ScreenState screenState

    function closeDashboard(): void {
        screenState.dashboard = false;
    }

    anchors.fill: parent
    anchors.margins: Tokens.padding.large
    spacing: Tokens.spacing.medium

    Action {
        icon: "screenshot_region"
        label: Tr.tr("Screenshot")
        onTriggered: {
            root.closeDashboard();
            Quickshell.execDetached(["distrobox-host-exec", "cosmic-screenshot"]);
        }
    }
    Action {
        icon: "screen_record"
        label: Tr.tr("Record")
        onTriggered: {
            root.closeDashboard();
            Recorder.openKooha();
        }
    }
    Action {
        icon: "content_paste"
        label: Tr.tr("Clipboard")
        onTriggered: {
            root.closeDashboard();
            Clipboard.open = true;
        }
    }
    Action {
        icon: "target"
        label: Tr.tr("Focus")
        active: FocusMode.enabled
        onTriggered: FocusMode.toggle()
    }
    Action {
        icon: "coffee"
        label: Tr.tr("Awake")
        active: IdleInhibitor.enabled
        onTriggered: IdleInhibitor.enabled = !IdleInhibitor.enabled
    }

    component Action: StyledRect {
        id: action

        required property string icon
        required property string label
        property bool active

        signal triggered

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: content.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: active ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

        StateLayer {
            color: action.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            onClicked: action.triggered()
        }

        ColumnLayout {
            id: content

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: action.icon
                color: action.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                fill: action.active ? 1 : 0
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: action.width - Tokens.padding.small * 2
                elide: Text.ElideRight
                text: action.label
                color: action.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }
    }
}
