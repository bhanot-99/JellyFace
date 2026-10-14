import QtQuick
import QtQuick.Effects
import Jellyface.Config
import qs.components
import qs.services

// A card of frosted glass: the wallpaper behind it, blurred, with a light veil of the theme colour and a thin light edge.
// It must sit directly in the same item as `wallpaper` (same coordinates), so its own x / y say which part to blur.
Item {
    id: root

    // the wallpaper image the card sits on (an Item, as big as the screen)
    required property Item wallpaper
    property real radius: Tokens.rounding.extraLarge
    property real tintAmount: 0.6
    default property alias content: inner.data

    // blurred crop of the wallpaper, cut to the card's shape
    MultiEffect {
        anchors.fill: parent
        source: ShaderEffectSource {
            sourceItem: root.wallpaper
            sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
        }
        maskSource: shape
        maskEnabled: true
        blurEnabled: true
        blur: 1
        blurMax: 48
        autoPaddingEnabled: false
        saturation: 0.35
        brightness: 0.05
    }

    Item {
        id: shape

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Colours.palette.m3surface, root.tintAmount)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.14)
    }

    Item {
        id: inner

        anchors.fill: parent
    }
}
