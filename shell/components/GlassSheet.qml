import QtQuick
import Jellyface.Config
import qs.services

// Frosted glass behind a popup window's bento tiles (clipboard, event form...): one sheet of the base glass a little
// larger than the tiles, so they sit on frosted glass instead of floating over whatever window is behind. Blur it with
// `BackgroundEffect.blurRegion: GlassRegion { pane: sheet }`. Not shown while glass is off.
StyledRect {
    property real bleed: Tokens.padding.large

    anchors.fill: parent
    anchors.margins: -bleed
    z: -1
    visible: Glass.enabled
    radius: Tokens.rounding.extraLarge + bleed
    color: Glass.smokeCovered
}
