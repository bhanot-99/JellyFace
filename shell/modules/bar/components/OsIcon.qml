import QtQuick
import Quickshell
import Jellyface.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.2)
    implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.2)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: {
            if (GlobalConfig.launcher.showOnHover)
                ShellState.forActive().launcher = true;
        }
        onClicked: {
            const screenState = ShellState.forActive();
            screenState.launcher = !screenState.launcher;
        }
    }

    ColouredIcon {
        anchors.centerIn: parent
        source: `file://${Quickshell.shellPath("../assets/ghost.svg")}`
        implicitSize: Math.round(Tokens.font.body.large.pointSize * 1.6)
        colour: Colours.palette.m3primary
    }
}
