import QtQuick
import Quickshell

// A blur region (for BackgroundEffect.blurRegion) exactly covering one frosted-glass pane, rounded corners included.
// Covers nothing while the pane is missing or hidden.
Region {
    property Item pane

    item: pane && pane.visible ? pane : null
    radius: item ? (item as Rectangle)?.radius ?? 0 : 0
    topLeftRadius: item ? (item as Rectangle)?.topLeftRadius ?? radius : 0
    topRightRadius: item ? (item as Rectangle)?.topRightRadius ?? radius : 0
    bottomLeftRadius: item ? (item as Rectangle)?.bottomLeftRadius ?? radius : 0
    bottomRightRadius: item ? (item as Rectangle)?.bottomRightRadius ?? radius : 0
}
