import QtQuick
import Quickshell.Widgets
import qs.services

ClippingRectangle {
    id: root

    // see StyledRect.glassRim
    property bool glassRim: Glass.enabled && color.a > 0.02 && color.a < 0.8 && radius >= 4 && width >= 20 && height >= 20

    color: "transparent"

    Loader {
        anchors.fill: parent
        z: -1
        active: root.glassRim
        sourceComponent: GlassRim {
            radius: root.radius
        }
    }

    Behavior on color {
        CAnim {}
    }
}
