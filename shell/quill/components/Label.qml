import QtQuick
import qs.quill

// Text in Quill's type scale. `size` is one of Theme's sizes (body by default).
Text {
    property int size: Theme.body
    property bool secondary
    property bool muted

    font.family: Theme.font
    font.pixelSize: size
    font.weight: size >= Theme.title ? Font.DemiBold : Font.Normal
    font.features: ({ "tnum": 1, "cv11": 1 })
    color: muted ? Theme.textMuted : secondary ? Theme.textSecondary : Theme.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    Behavior on color {
        ColorAnim {}
    }
}
