import QtQuick
import QtQuick.Shapes
import qs.quill

// The "glass sails" artwork: a soft sky and five translucent curved sails with lit edges, overlapping like layers of
// frosted glass. Draws any size (the desktop, a lock screen, a thumbnail in Appearance). `mood` is a Moods name;
// `living` lays the time-of-day tint over it, `darken` the night shade used by the dark theme.
Item {
    id: root

    property string mood: QuillConfig.wallpaper
    // "system": COSMIC's own wallpaper is shown instead of the sails (the sails stay as the fallback)
    readonly property bool system: mood === "system" && Moods.systemWallpaper !== ""
    property bool living: QuillConfig.living
    property bool darken: Theme.dark
    readonly property var m: Moods.mood(mood)
    readonly property real w: width
    readonly property real h: height
    // stroke width of the lit edges: thin on a thumbnail, 1.5 px on a screen
    readonly property real edge: Math.max(0.6, Math.min(1.6, width / 900))

    // [left foot, apex x, right foot, apex height] as fractions of the screen, back to front
    readonly property var geometry: [[-0.12, 0.2, 0.52, 0.12], [0.18, 0.47, 0.8, 0.05], [0.42, 0.68, 1.02, 0.22], [-0.06, 0.16, 0.5, 0.36], [0.52, 0.86, 1.18, 0.34]]

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: root.m.sky[0] }
            GradientStop { position: 0.55; color: root.m.sky[1] }
            GradientStop { position: 1; color: root.m.sky[2] }
        }
    }

    // a horizontal wash so the sky is not one flat vertical ramp
    Rectangle {
        anchors.fill: parent
        opacity: 0.55
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.alpha(root.m.sky[0], 0.9) }
            GradientStop { position: 0.6; color: "transparent" }
            GradientStop { position: 1; color: Qt.alpha(root.m.sky[2], 0.8) }
        }
    }

    component Sail: ShapePath {
        id: sail

        required property int index
        readonly property var g: root.geometry[index]
        readonly property real bl: g[0] * root.w
        readonly property real ax: g[1] * root.w
        readonly property real br: g[2] * root.w
        readonly property real ay: g[3] * root.h
        readonly property real by: root.h * 1.04
        readonly property color c: root.m.sails[index]

        strokeColor: Qt.rgba(1, 1, 1, root.m.dark ? 0.32 : 0.75)
        strokeWidth: root.edge
        fillGradient: LinearGradient {
            x1: sail.ax
            y1: sail.ay
            x2: sail.ax - root.w * 0.05
            y2: sail.by
            GradientStop { position: 0; color: Qt.alpha(sail.c, root.m.dark ? 0.85 : 0.78) }
            GradientStop { position: 0.65; color: Qt.alpha(Qt.lighter(sail.c, root.m.dark ? 1.15 : 1.06), root.m.dark ? 0.6 : 0.5) }
            GradientStop { position: 1; color: Qt.alpha(Qt.lighter(sail.c, 1.2), root.m.dark ? 0.45 : 0.35) }
        }
        startX: bl
        startY: by

        PathCubic {
            x: sail.ax
            y: sail.ay
            control1X: sail.bl + (sail.ax - sail.bl) * 0.38
            control1Y: sail.by - (sail.by - sail.ay) * 0.58
            control2X: sail.ax - (sail.ax - sail.bl) * 0.2
            control2Y: sail.ay
        }
        PathCubic {
            x: sail.br
            y: sail.by
            control1X: sail.ax + (sail.br - sail.ax) * 0.24
            control1Y: sail.ay
            control2X: sail.br - (sail.br - sail.ax) * 0.5
            control2Y: sail.by - (sail.by - sail.ay) * 0.52
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Sail { index: 0 }
        Sail { index: 1 }
        Sail { index: 2 }
        Sail { index: 3 }
        Sail { index: 4 }
    }

    // the time of day (living) and the dark theme's night shade, only over light moods
    Rectangle {
        anchors.fill: parent
        visible: !root.m.dark
        color: {
            const t = root.living ? Moods.tint : [0, 0, 0, 0];
            const night = root.darken ? 0.5 : 0;
            if (night > t[3])
                return Qt.rgba(0.07, 0.06, 0.24, night);
            return Qt.rgba(t[0], t[1], t[2], t[3]);
        }

        Behavior on color {
            ColorAnim { duration: 1200 }
        }
    }

    Image {
        visible: root.system
        anchors.fill: parent
        source: root.system ? Moods.systemWallpaper : ""
        sourceSize: Qt.size(Math.max(64, root.width), Math.max(64, root.height))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
