//@ pragma Env QS_CRASHREPORT_URL=https://github.com/bhanot-99/JellyFace/issues
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/areapicker"
import "modules/lock"
// never used as a type here (Quill is compiled by path below); this import is only how Quickshell finds quill/ and
// its qs.quill module
import "quill" as QuillFiles
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root

    // Which interface runs: "quill" (the new one, quill/) or Classic. Set by `jellyface ui`, which writes
    // ~/.config/jellyface/ui and restarts the shell; scripts/run.sh passes it in as JF_UI.
    readonly property bool wantQuill: Quickshell.env("JF_UI") === "quill"
    // Quill is compiled separately: if it ever fails to load, Classic comes up instead of a desktop with nothing on it
    readonly property Component quillShell: wantQuill ? Qt.createComponent(Qt.resolvedUrl("quill/QuillShell.qml")) : null
    readonly property bool quill: quillShell !== null && quillShell.status === Component.Ready

    // Live reload on every saved QML file is a development aid: for everyone else it only meant half-saved edits (or a
    // `git pull`) briefly loading a broken shell. JF_DEV=1 jellyface start turns it back on.
    settings.watchFiles: Quickshell.env("JF_DEV") === "1"

    Component.onCompleted: {
        if (wantQuill && !quill)
            console.warn(`quill: failed to load, starting Classic instead: ${quillShell?.errorString() ?? ""}`);
        // tests/quill-check.sh: compile every Quill type through its module, wrapped in a Component so nothing is
        // created or shown. This also covers surfaces that are only built when opened, and gives the real error behind
        // "Type X unavailable".
        for (const f of (Quickshell.env("JF_QUILL_PROBE") ?? "").split(" ").filter(f => f)) {
            const parts = f.replace(/\.qml$/, "").split("/");
            const type = parts.pop();
            try {
                Qt.createQmlObject(`import QtQuick\nimport qs.${parts.join(".")}\nComponent { ${type} {} }`, root, "probe").destroy();
            } catch (e) {
                console.warn(`quill: probe ${f}: ${(e.qmlErrors ?? []).map(q => `${q.fileName.replace(/^.*\/qs\//, "")}:${q.lineNumber}: ${q.message}`).join(" | ") || e.message}`);
            }
        }
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    Binding {
        target: LockBridge
        property: "lock"
        value: lock.lock
    }

    Binding {
        target: LockBridge
        property: "pam"
        value: lock.pam
    }

    GSFLoader {}
    ServiceLoader {}

    // Shared by both interfaces: the lock screen (and its safety net), idle handling, battery warnings, area picker
    AreaPicker {}
    Lock {
        id: lock
    }
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }

    LazyLoader {
        active: !root.quill

        ClassicShell {}
    }

    LazyLoader {
        active: root.quill
        component: root.quillShell
    }
}
