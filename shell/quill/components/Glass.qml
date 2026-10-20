import QtQuick
import QtQuick.Effects
import qs.quill

// A pane of Quill glass (use color: Theme.sheet for one floating over app windows): translucent fill over the compositor's blur, a 1 px light rim with a brighter top edge, and a
// soft shadow. Blur it by putting `BlurRegion { pane: thisGlass.body }` in its window's blur region.
Item {
    id: root

    property alias radius: body.radius
    property color color: Theme.pane
    property bool shadow: true
    property real shadowStrength: 1
    readonly property alias body: body
    default property alias content: body.data

    RectangularShadow {
        anchors.fill: body
        visible: root.shadow
        radius: body.radius
        blur: 48
        spread: -6
        offset.y: 14
        color: Qt.alpha(Theme.shadow, Theme.shadow.a * root.shadowStrength)
    }

    Rectangle {
        id: body

        anchors.fill: parent
        radius: Theme.radiusPane
        color: root.color
        border.width: 1
        border.color: Theme.rimSoft

        Behavior on color {
            ColorAnim {}
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.haze
        }

        // the lit top edge of the glass
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 0.5
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius * 1.2
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Theme.rim }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
}
