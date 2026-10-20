import QtQuick
import QtQuick.Shapes
import qs.quill

// A round gauge: a soft track and an arc for the value (0-1), with whatever goes in the middle as children.
Item {
    id: root

    property real value
    property color color: Theme.accent
    property real thickness: 9
    default property alias content: middle.data

    implicitWidth: 120
    implicitHeight: 120

    property real shown: value

    Behavior on shown {
        Anim { duration: Theme.slow }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.well
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: 135
                sweepAngle: 270
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: 135
                sweepAngle: Math.max(0.5, 270 * Math.max(0, Math.min(1, root.shown)))
            }
        }
    }

    Item {
        id: middle

        anchors.fill: parent
    }
}
