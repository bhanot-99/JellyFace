pragma ComponentBehavior: Bound

import QtQuick

// Micro-noise film grain texture: when tiled at low opacity (0.02 - 0.04) over frosted glass or blurred surfaces,
// it scatters digital color banding and gives the glass an organic, physical etched texture.
Image {
    id: root

    property real grainOpacity: 0.035

    anchors.fill: parent
    fillMode: Image.Tile
    source: "../../assets/noise.png"
    opacity: grainOpacity
    asynchronous: true
    smooth: false
}
