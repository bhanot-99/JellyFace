import QtQuick
import qs.quill

// A Material Symbols Rounded glyph at Quill's light stroke. `filled` swaps to the solid form (selected states).
Text {
    property string name
    property int size: 20
    property bool filled

    text: name
    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 350, "opsz": Math.max(20, Math.min(48, size)), "GRAD": 0 })
    color: Theme.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    Behavior on color {
        ColorAnim {}
    }
}
