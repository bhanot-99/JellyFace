import QtQuick
import qs.quill

// A progress bar whose played part is a gentle wave that flows while `flowing` (Classic's media slider, in Quill's
// colours); the rest is a flat track. Click or drag to seek: `released(value)` once, at the end.
// The wave is painted once (a period wider than the bar) and slid sideways by the render thread, so a playing track
// costs no repaint per frame.
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
    signal released(real value)

    implicitWidth: 300
    implicitHeight: 24

    // the flat track ahead
    Rectangle {
        x: knob.x + knob.width + 4
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - x)
        height: 4
        radius: 2
        color: Theme.well
    }

    // the played part: the wave (or a flat line while paused), cut off just before the knob
    Item {
        id: played

        x: 2
        width: Math.max(0, knob.x - 4 - x)
        height: root.height
        clip: true

        Rectangle {
            visible: !root.flowing
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: root.fill
        }

        Canvas {
            id: wave

            visible: root.flowing
            width: root.width + root.wavelength
            height: root.height

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            Connections {
                function onFillChanged(): void {
                    wave.requestPaint();
                }

                function onAmplitudeChanged(): void {
                    wave.requestPaint();
                }

                function onWavelengthChanged(): void {
                    wave.requestPaint();
                }

                target: root
            }

            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.strokeStyle = root.fill;
                c.lineWidth = 4;
                c.lineCap = "round";
                c.beginPath();
                const mid = height / 2;
                for (let x = 0; x <= width; x += 1.5) {
                    const y = mid + Math.sin(x / root.wavelength * Math.PI * 2) * root.amplitude;
                    x === 0 ? c.moveTo(x, y) : c.lineTo(x, y);
                }
                c.stroke();
            }

            // one wavelength to the right and back to the start, which looks the same: an endless flow
            XAnimator on x {
                running: root.flowing && root.visible
                from: -root.wavelength
                to: 0
                duration: 1800
                loops: Animation.Infinite
            }
        }
    }

    // the knob: a tall rounded pill, as on Classic's slider
    Rectangle {
        id: knob

        x: root.shown * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 5
        height: root.dragging ? 24 : area.containsMouse ? 22 : 20
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
        hoverEnabled: true
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
