// One full-screen layer surface per screen, used by the real greeter (shell.qml loads this unless in test mode)
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    property Component content

    model: Quickshell.screens

    PanelWindow {
        required property var modelData

        screen: modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "#232423"

        Loader {
            anchors.fill: parent
            sourceComponent: content
        }
    }
}
