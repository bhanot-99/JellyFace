import "../modules/island"
import QtQuick
import Quickshell
import qs.services
import qs.quill
import qs.quill.stage
import qs.quill.surfaces.desktop

// Quill: JellyFace's second interface (docs/NEW-UI-PLAN.md). shell.qml loads this or Classic, never both. The lock
// screen, idle handling, battery warnings and every service are shared with Classic; everything drawn is Quill's own.
Scope {
    id: root

    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/Inter.ttf")
    }

    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/JetBrainsMono.ttf")
    }

    Component.onCompleted: {
        // load these now: the workspace and window helpers start with them, and the state socket must be listening
        // before the first shortcut arrives
        CosmicWs;
        CosmicWindows;
        QuillState;
        QuillConfig;
        QuillApps;
        DeepFocus;
        Power;
        LastMedia;
        console.info("quill: loaded");
    }

    Wallpaper {}
    SideBar {}
    Dock {}
    LevelBars {}
    TopEdge {}

    // Classic's Dynamic Island exactly as it is (pitch black), but out of sight while idle: it appears only for media,
    // a timer, a notification, volume or charging. It steps aside while the dashboard, which drops from the same spot,
    // is open.
    DynamicIsland {
        idleVisible: false
        hidden: QuillState.open === "today"
    }
    Toasts {}
    Stage {}
}
