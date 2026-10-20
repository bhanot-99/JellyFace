pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.drift
import qs.drift.components

// Drift's wallpaper: the glass sails on the background layer of every screen. The "system" mood draws nothing, so
// COSMIC's own wallpaper shows.
Variants {
    model: DriftConfig.wallpaper === "system" ? [] : Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        WlrLayershell.namespace: "jellyface-drift-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "black"

        Sails {
            anchors.fill: parent
        }
    }
}
