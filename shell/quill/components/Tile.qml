import QtQuick
import qs.quill

// A card inside a glass pane. Clickable when it has a handler: hover lightens it, a press sinks it a little.
Rectangle {
    id: root

    property bool interactive: true
    property bool selected
    property bool focused // keyboard focus ring
    readonly property alias hovered: area.containsMouse
    readonly property alias pressed: area.pressed
    signal clicked
    signal rightClicked

    radius: Theme.radiusTile
    color: selected ? Theme.accentSoft : hovered && interactive ? Theme.tileHover : Theme.tile
    border.width: focused ? 2 : 1
    border.color: focused ? Theme.accent : Theme.rimSoft
    scale: pressed && interactive ? 0.98 : 1

    Behavior on color {
        ColorAnim { duration: Theme.fast }
    }
    Behavior on scale {
        Anim { duration: Theme.fast }
    }
    Behavior on border.color {
        ColorAnim { duration: Theme.fast }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        z: -1
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
