import QtQuick
import QtQuick.Effects
import qs.quill

// A horizontal slider (0-1). While it is dragged a dark bubble above the knob shows the value ("62%").
// `moved(value)` fires while dragging, `released(value)` once at the end; scrolling steps 5% a notch (a touchpad moves
// it smoothly).
Item {
    id: root

    property real value
    property string icon
    property color fill: Theme.accent
    property bool showBubble: true
    property string bubbleText: `${Math.round(shown * 100)}%`
    readonly property bool dragging: area.pressed
    // the knob follows the finger at once, and the model's value otherwise (eased)
    property real shown: dragging ? dragValue : value
    property real dragValue
    signal moved(real value)
    signal released(real value)

    implicitWidth: 220
    implicitHeight: 28
    opacity: enabled ? 1 : 0.45

    Behavior on shown {
        enabled: !root.dragging
        Anim { duration: Theme.fast }
    }

    Icon {
        id: lead

        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 18
        color: Theme.textSecondary
        width: visible ? 22 : 0
    }

    Item {
        id: track

        anchors.left: lead.right
        anchors.leftMargin: root.icon !== "" ? Theme.s2 : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Theme.well
        }

        Rectangle {
            width: Math.max(height, knob.x + knob.width / 2)
            height: parent.height
            radius: 3
            color: root.fill

            Behavior on color {
                ColorAnim {}
            }
        }

        RectangularShadow {
            anchors.fill: knob
            radius: knob.radius
            blur: 10
            offset.y: 2
            color: Qt.rgba(0.1, 0.12, 0.3, 0.25)
        }

        Rectangle {
            id: knob

            width: root.dragging ? 22 : area.containsMouse ? 20 : 18
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(1, root.shown)) * (track.width - width)
            color: "#FFFFFF"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.06)

            Behavior on width {
                Anim { duration: Theme.fast }
            }
        }

        // the value bubble
        Rectangle {
            visible: opacity > 0
            opacity: root.dragging && root.showBubble ? 1 : 0
            anchors.bottom: knob.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: knob.horizontalCenter
            width: bubble.implicitWidth + 14
            height: 22
            radius: 11
            color: "#1B1F3B"
            scale: root.dragging ? 1 : 0.8

            Behavior on opacity {
                Anim { duration: Theme.fast }
            }
            Behavior on scale {
                Anim { duration: Theme.fast }
            }

            Text {
                id: bubble

                anchors.centerIn: parent
                text: root.bubbleText
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                color: "#FFFFFF"
            }
        }
    }

    MouseArea {
        id: area

        function valueAt(x: real): real {
            const p = mapToItem(track, x, 0).x;
            return Math.max(0, Math.min(1, (p - knob.width / 2) / (track.width - knob.width)));
        }

        anchors.fill: track
        anchors.topMargin: -12
        anchors.bottomMargin: -12
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: e => {
            root.dragValue = valueAt(e.x);
            root.moved(root.dragValue);
        }
        onPositionChanged: e => {
            if (!pressed)
                return;
            root.dragValue = valueAt(e.x);
            root.moved(root.dragValue);
        }
        onReleased: root.released(root.dragValue)
        onWheel: w => {
            if (w.angleDelta.y === 0)
                return;
            const v = Math.max(0, Math.min(1, root.value + w.angleDelta.y / 120 * 0.05));
            root.moved(v);
            root.released(v);
        }
    }
}
