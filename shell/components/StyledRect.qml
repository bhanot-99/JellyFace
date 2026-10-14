import QtQuick
import qs.services

Rectangle {
    id: root

    // Frosted glass: translucent panes (cards, tiles, pills) get a thin top-lit rim. On by default for anything that
    // looks like a pane; set false to opt out.
    property bool glassRim: Glass.enabled && color.a > 0.02 && color.a < 0.8 && radius >= 4 && width >= 20 && height >= 20

    color: "transparent"

    Loader {
        anchors.fill: parent
        z: -1 // under the pane's own fill and content, so it never covers text
        active: root.glassRim
        sourceComponent: GlassRim {
            radius: root.radius
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
        }
    }

    Behavior on color {
        CAnim {}
    }
}
