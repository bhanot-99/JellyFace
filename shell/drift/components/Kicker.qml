import QtQuick
import qs.drift

// The small spaced-out monospace caption above a section ("02 — CONTROL CENTER").
Text {
    font.family: Theme.mono
    font.pixelSize: Theme.caption
    font.weight: Font.Medium
    font.letterSpacing: 2.2
    font.capitalization: Font.AllUppercase
    color: Theme.kicker
    opacity: 0.85
    renderType: Text.NativeRendering
}
