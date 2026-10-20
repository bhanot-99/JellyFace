import "../modules/island"
import QtQuick
import Quickshell
import qs.services
import qs.drift
import qs.drift.stage
import qs.drift.surfaces.desktop

// Drift: JellyFace's second interface (docs/NEW-UI-PLAN.md). shell.qml loads this or Classic, never both. The lock
// screen, idle handling, battery warnings and every service are shared with Classic; everything drawn is Drift's own.
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
        DriftState;
        DriftConfig;
        DriftApps;
        DeepFocus;
        Power;
        LastMedia;
        console.info("drift: loaded");
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
        hidden: DriftState.open === "today"
    }
    Toasts {}
    Stage {}
}
