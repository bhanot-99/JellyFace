import QtQuick
import qs.quill

// An on/off switch. The knob springs a little; the track fades to the accent.
Item {
    id: root

    property bool checked
    signal toggled(bool checked)

    implicitWidth: 44
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.well
        border.width: 1
        border.color: root.checked ? Qt.alpha(Theme.accent, 0.4) : Theme.rimSoft

        Behavior on color {
            ColorAnim {}
        }
    }

    Rectangle {
        id: knob

        width: root.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: "#FFFFFF"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.06)

        Behavior on x {
            SpringAnimation {
                spring: 5
                damping: 0.38
                epsilon: 0.25
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
