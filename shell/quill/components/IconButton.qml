import QtQuick
import qs.quill

// A round glass button with one icon. `active` fills it with the accent (a quick toggle that is on).
Rectangle {
    id: root

    property string icon
    property bool active
    property color activeColor: Theme.accent
    property int size: 44
    property bool focused
    property string tip
    readonly property alias hovered: area.containsMouse
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: active ? activeColor : area.containsMouse ? Theme.tileHover : Theme.tile
    border.width: focused ? 2 : 1
    border.color: focused ? Theme.accent : active ? Qt.alpha(activeColor, 0.6) : Theme.rimSoft
    scale: area.pressed ? 0.92 : 1

    Behavior on color {
        ColorAnim { duration: Theme.fast }
    }
    Behavior on scale {
        Anim { duration: Theme.fast }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: Math.round(root.size * 0.45)
        filled: root.active
        color: root.active ? Theme.accentText : Theme.text
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
