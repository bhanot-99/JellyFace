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
        console.info("drift: loaded");
    }

    Wallpaper {}
    SideBar {}
    Dock {}
    LevelBars {}
    TopEdge {}

    // Classic's Dynamic Island, in Drift's colours; it steps aside while Today (which drops from the same spot) is open
    DynamicIsland {
        hidden: DriftState.open === "today"
        colBg: Theme.dark ? Qt.rgba(0.11, 0.1, 0.24, 0.97) : Qt.rgba(0.985, 0.985, 1, 0.97)
        colTextPrimary: Theme.text
        colTextSecondary: Theme.textSecondary
        colTextTertiary: Theme.textMuted
        colEqGreen: Theme.good
        colAccentPink: Theme.accent
        colTimer: Theme.warn
        colDanger: Theme.bad
        colScrubTrack: Theme.well
        colArtBg: Theme.tile
    }
    Toasts {}
    Stage {}
}
