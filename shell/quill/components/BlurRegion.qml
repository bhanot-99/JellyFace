import QtQuick
import Quickshell

// The blur behind one glass pane (BackgroundEffect.blurRegion), rounded corners included; nothing while it is hidden.
Region {
    property Item pane

    item: pane && pane.visible && pane.opacity > 0 ? pane : null
    radius: item ? (item as Rectangle)?.radius ?? 0 : 0
}
