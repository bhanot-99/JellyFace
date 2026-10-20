import QtQuick
import QtQuick.Shapes
import qs.quill

// A small "working on it" arc.
Item {
    id: root

    property int size: 16
    property color color: Theme.textSecondary

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        RotationAnimator on rotation {
            running: root.visible
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: Math.max(1.5, root.size / 9)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.size / 2 - 1.5
                radiusY: root.size / 2 - 1.5
                startAngle: 0
                sweepAngle: 270
            }
        }
    }
}
