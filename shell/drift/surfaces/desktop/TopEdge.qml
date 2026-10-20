import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.drift

// Classic's dashboard gesture, for Drift's Today: rest the cursor on the top edge near the middle and Today slides
// down. While it waits (services/DashboardPeek) the Dynamic Island stretches towards it, so moving away calls it off.
Scope {
    id: root

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: !CosmicWindows.fullscreen && DriftState.open === ""
        WlrLayershell.namespace: "jellyface-drift-top-edge"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        implicitWidth: 480
        implicitHeight: 2
        color: "transparent"

        Item {
            anchors.fill: parent

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        DashboardPeek.dwell = 300;
                        wait.restart();
                    } else {
                        wait.stop();
                    }
                }
            }
        }
    }

    Timer {
        id: wait

        interval: DashboardPeek.dwell
        onRunningChanged: DashboardPeek.active = running
        onTriggered: DriftState.show("today")
    }
}
