import QtQuick
import qs.quill

// A small glass pill: a top-bar status group, a chip, a caption bubble.
Rectangle {
    id: root

    property bool interactive
    property bool active
    readonly property alias hovered: area.containsMouse
    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: 12
    signal clicked

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: 28
    radius: height / 2
    color: active ? Theme.accentSoft : interactive && area.containsMouse ? Theme.tileHover : Theme.pane
    border.width: 1
    border.color: Theme.rimSoft

    Behavior on color {
        ColorAnim { duration: Theme.fast }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 8
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
