pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Jellyface.Config
import qs.modules.bar as Bar

// Where the compositor blurs behind the shell for the frosted-glass look: the same shape as the input mask (Regions.qml),
// but with rounded corners, so no blurred-but-unpainted squares show at the frame's inner corners or the drawers' free
// corners. Each drawer is extended by its radius into the frame it hangs from, so only its free corners are rounded.
Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real thickness: win.borderThickness
    readonly property real ext: win.contentItem.Tokens.rounding.extraLarge // read through contentItem: a Region has no screen

    // the frame's inner hole (Xor with the whole window = the frame), minus the drawers below
    x: bar.implicitWidth
    y: thickness
    width: win.width - bar.implicitWidth - thickness
    height: win.height - thickness * 2
    radius: win.borderRounding
    intersection: Intersection.Xor

    Top {
        panel: root.panels.dashboard
        visibleSize: panel.height * (1 - root.panels.dashboard.offsetScale)
    }

    Top {
        panel: root.panels.notifications
        visibleSize: panel.height
    }

    Left {
        panel: root.panels.launcher
        visibleSize: panel.width * (1 - root.panels.launcher.offsetScale)
    }

    Left {
        panel: root.panels.popoutsWrapper
        visibleSize: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    Right {
        id: sidebarR

        panel: root.panels.sidebar
        visibleSize: panel.width * (1 - root.panels.sidebar.offsetScale)
    }

    Right {
        id: sessionR

        panel: root.panels.sessionWrapper
        visibleSize: root.panels.session.width * (1 - root.panels.session.offsetScale)
        inset: sidebarR.visibleSize
    }

    Right {
        panel: root.panels.osdWrapper
        visibleSize: root.panels.osd.width * (1 - root.panels.osd.offsetScale)
        inset: sessionR.inset + sessionR.visibleSize
    }

    Region {
        readonly property Item panel: root.panels.utilities
        readonly property real visibleSize: panel.height * (1 - root.panels.utilities.offsetScale)

        x: panel.x + root.bar.implicitWidth
        y: root.win.height - root.thickness - visibleSize
        width: panel.width
        height: visibleSize > 0 ? visibleSize + root.ext : 0
        radius: root.ext
        intersection: Intersection.Subtract
    }

    component Top: Region {
        required property Item panel
        required property real visibleSize

        x: panel.x + root.bar.implicitWidth
        y: root.thickness - root.ext
        width: panel.width
        height: visibleSize > 0 ? visibleSize + root.ext : 0
        radius: root.ext
        intersection: Intersection.Subtract
    }

    component Left: Region {
        required property Item panel
        required property real visibleSize

        x: panel.x + root.bar.implicitWidth - root.ext
        y: panel.y + root.thickness
        width: visibleSize > 0 ? visibleSize + root.ext : 0
        height: panel.height
        radius: root.ext
        intersection: Intersection.Subtract
    }

    component Right: Region {
        required property Item panel
        required property real visibleSize
        property real inset // width of the drawers already hanging further right (session sits left of the sidebar)

        x: root.win.width - root.thickness - inset - visibleSize
        y: panel.y + root.thickness
        width: visibleSize > 0 ? visibleSize + root.ext : 0
        height: panel.height
        radius: root.ext
        intersection: Intersection.Subtract
    }
}
