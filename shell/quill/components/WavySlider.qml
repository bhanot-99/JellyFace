import QtQuick
import qs.quill

// A progress bar whose played part is a gentle wave that flows while `flowing` (Classic's media slider, in Quill's
// colours); the rest is a flat track. Click or drag to seek: `released(value)` once, at the end.
Item {
    id: root

    property real value
    property bool flowing
    property color fill: Theme.accent
    property real amplitude: 3.2
    property real wavelength: 26
    readonly property bool dragging: area.pressed
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))
    property real dragValue
    property real phase
    signal released(real value)

    implicitWidth: 300
    implicitHeight: 24

    NumberAnimation on phase {
        running: root.flowing && root.visible
        from: 0
        to: Math.PI * 2
        duration: 1800
        loops: Animation.Infinite
    }

    onPhaseChanged: wave.requestPaint()
    onShownChanged: wave.requestPaint()
    onFillChanged: wave.requestPaint()

    // the flat track ahead
    Rectangle {
        x: knob.x + knob.width + 4
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - x)
        height: 4
        radius: 2
        color: Theme.well
    }

    Canvas {
        id: wave

        anchors.fill: parent
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const end = Math.max(0, knob.x - 4);
            if (end < 2)
                return;
            c.strokeStyle = root.fill;
            c.lineWidth = 4;
            c.lineCap = "round";
            c.beginPath();
            const mid = height / 2, a = root.flowing ? root.amplitude : 0;
            for (let x = 2; x <= end; x += 1.5) {
                const y = mid + Math.sin(x / root.wavelength * Math.PI * 2 - root.phase) * a;
                x === 2 ? c.moveTo(x, y) : c.lineTo(x, y);
            }
            c.stroke();
        }
    }

    // the knob: a tall rounded pill, as on Classic's slider
    Rectangle {
        id: knob

        x: root.shown * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 5
        height: root.dragging ? 24 : 20
        radius: 2.5
        color: root.fill

        Behavior on height {
            Anim { duration: Theme.fast }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onPressed: e => root.dragValue = Math.max(0, Math.min(1, e.x / width))
        onPositionChanged: e => {
            if (pressed)
                root.dragValue = Math.max(0, Math.min(1, e.x / width));
        }
        onReleased: root.released(root.dragValue)
    }
}
