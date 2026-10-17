//@ pragma Env QS_CRASHREPORT_URL=https://github.com/bhanot-99/JellyFace/issues
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/dock"
import "modules/clipboard"
import "modules/jellypanel"
import "modules/island"
import "modules/agenda"
import "modules/areapicker"
import "modules/lock"
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root

    // Live reload on every saved QML file is a development aid: for everyone else it only meant half-saved edits (or a
    // `git pull`) briefly loading a broken shell. JF_DEV=1 jellyface start turns it back on.
    settings.watchFiles: Quickshell.env("JF_DEV") === "1"

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    GSFLoader {}
    ServiceLoader {}

    Dock {}
    JellyPanelWindow {}
    DynamicIsland {}
    Drawers {}
    AreaPicker {}
    ClipboardPopup {}
    Agenda {}
    EventForm {}
    Lock {
        id: lock
    }

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
