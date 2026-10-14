pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import JellyFace.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property real maxHeight: screen.height - Config.border.thickness * 2 - Tokens.padding.extraLarge * 2

    // The panel is centred vertically for its fullest state (a full list); its top edge then stays put while the
    // list grows and shrinks, so the search box does not jump around while you type.
    readonly property real fullHeight: Math.min(maxHeight, (Tokens.sizes.launcher.itemHeight + Tokens.spacing.small) * Config.launcher.maxShown + Tokens.padding.large * 3 + 64)

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => content.implicitHeight);
        else
            implicitHeight = implicitHeight; // Break binding during close anim
    }

    visible: offsetScale < 1
    anchors.leftMargin: (-implicitWidth - 5) * offsetScale
    y: Math.round((parent.height - fullHeight) / 2)
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 630 // Hard coded fallback for first open
    opacity: 1 - offsetScale

    Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight
        }
    }
}
