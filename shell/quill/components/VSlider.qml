import QtQuick
import qs.quill

// A tall rounded slider that fills from the bottom (the right-edge volume and brightness bars). The icon sits at the
// bottom inside the fill; drag or scroll to change it.
Item {
    id: root

    property real value
    property string icon
    property real step: 0.05
    readonly property bool dragging: area.pressed
    property real shown: dragging ? dragValue : value
    property real dragValue
    signal moved(real value)

    implicitWidth: 44
    implicitHeight: 172

    Behavior on shown {
        enabled: !root.dragging
        Anim { duration: Theme.fast }
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: width / 2
        color: Theme.well
        clip: true

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(parent.width, parent.height * Math.max(0, Math.min(1, root.shown)))
            radius: parent.radius
            color: area.containsMouse || root.dragging ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
            opacity: root.shown > 0.001 ? 1 : 0.35

            Behavior on color {
                ColorAnim { duration: Theme.fast }
            }
        }
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        name: root.icon
        size: 19
        filled: true
        color: root.shown > 0.08 ? "#FFFFFF" : Theme.text
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12
        text: Math.round(root.shown * 100)
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
        color: root.shown > 0.92 ? "#FFFFFF" : Theme.textSecondary
    }

    MouseArea {
        id: area

        function valueAt(y: real): real {
            return Math.max(0, Math.min(1, 1 - y / height));
        }

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: e => {
            root.dragValue = valueAt(e.y);
            root.moved(root.dragValue);
        }
        onPositionChanged: e => {
            if (pressed) {
                root.dragValue = valueAt(e.y);
                root.moved(root.dragValue);
            }
        }
        // a notch is one step; a touchpad's small deltas move it smoothly
        onWheel: w => {
            if (w.angleDelta.y !== 0)
                root.moved(Math.max(0, Math.min(1, root.value + w.angleDelta.y / 120 * root.step)));
        }
    }
}
