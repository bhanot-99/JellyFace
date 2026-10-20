import QtQuick
import QtQuick.Effects
import qs.quill

// A keyboard key as a little glass pill ("Super", "Space", "Enter ↵"). `lit` is a key being pressed right now.
Item {
    id: root

    property string key
    property bool lit
    property bool large

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + (large ? 28 : 16))
    implicitHeight: large ? 40 : 24

    RectangularShadow {
        anchors.fill: cap
        radius: cap.radius
        blur: 8
        offset.y: 2
        color: Qt.rgba(0.1, 0.12, 0.3, 0.18)
    }

    Rectangle {
        id: cap

        anchors.fill: parent
        radius: root.large ? 12 : 7
        color: root.lit ? Theme.accentSoft : Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : "#FFFFFF"
        border.width: 1
        border.color: root.lit ? Theme.accent : Theme.rimSoft

        Behavior on color {
            ColorAnim { duration: Theme.fast }
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.key
        font.family: Theme.font
        font.pixelSize: root.large ? 14 : 11
        font.weight: Font.Medium
        color: Theme.text
    }
}
