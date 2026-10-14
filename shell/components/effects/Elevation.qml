import QtQuick
import QtQuick.Effects
import qs.components
import qs.services

RectangularShadow {
    property int level
    property real dp: [0, 1, 3, 6, 8, 12][level]

    color: Qt.alpha(Colours.palette.m3shadow, Glass.enabled ? 0.28 : 0.7) // under glass a heavy shadow shows through as a smudge
    blur: (dp * 5) ** 0.7
    spread: -dp * 0.3 + (dp * 0.1) ** 2
    offset.y: dp / 2

    Behavior on dp {
        Anim {
            type: Anim.SlowEffects
        }
    }
}
