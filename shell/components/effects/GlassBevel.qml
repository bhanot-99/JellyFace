pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Directional specular bevel for frosted-glass panes:
// A top-lit specular edge fading down to a soft ambient refraction rim.
Item {
    id: root

    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    property real bevelOpacity: 1.0

    anchors.fill: parent
    opacity: bevelOpacity

    // 1. Top specular edge highlight
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
    }

    // 2. Interior light sheen fading from the top edge downwards
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        topLeftRadius: Math.max(0, root.topLeftRadius - 1)
        topRightRadius: Math.max(0, root.topRightRadius - 1)
        bottomLeftRadius: Math.max(0, root.bottomLeftRadius - 1)
        bottomRightRadius: Math.max(0, root.bottomRightRadius - 1)
        color: "transparent"

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
            }
            GradientStop {
                position: 0.35
                color: "transparent"
            }
        }
    }
}
