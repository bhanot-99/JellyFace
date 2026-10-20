pragma Singleton

import ".."
import QtQuick
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import Jellyface.Services
import qs.services
import qs.utils

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(GlobalConfig.launcher.actionPrefix.length);
    }

    // The default actions were written for upstream's `caelestia` CLI. `jellyface shell <target> <function>` becomes an
    // IPC call to this shell (the jellyface CLI has no `shell` command); null = nothing JellyFace can run
    // (`jellyface wallpaper`: COSMIC owns the wallpaper). Other commands are returned unchanged.
    function runnable(command: var): var {
        if (command[0] !== "jellyface")
            return command;
        if (command[1] === "shell" && command.length > 3)
            return ["quickshell", "ipc", "-p", Quickshell.shellDir, "call", ...command.slice(2)];
        return null;
    }

    list: variants.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.actions

    Variants {
        id: variants

        model: {
            const enableDangerous = GlobalConfig.launcher.enableDangerousActions;
            return GlobalConfig.launcher.actions.values.filter(a => a.enabled && (enableDangerous || !a.dangerous) && root.runnable(a.command ?? []) !== null);
        }

        Action {}
    }

    component Action: QtObject {
        required property var modelData
        readonly property string name: modelData.name ? Tr.trMarked(modelData.name) : Tr.trCtx("Unnamed", "launcher action with no name")
        readonly property string desc: modelData.description ? Tr.trMarked(modelData.description) : Tr.trCtx("No description", "launcher action with no description")
        readonly property string icon: modelData.icon ?? "help_outline"
        readonly property list<string> command: modelData.command ?? []
        readonly property bool enabled: modelData.enabled ?? true
        readonly property bool dangerous: modelData.dangerous ?? false

        function onClicked(list: AppList): void {
            if (command.length === 0)
                return;

            if (command[0] === "autocomplete" && command.length > 1) {
                list.search.text = `${GlobalConfig.launcher.actionPrefix}${command[1]} `;
            } else if (command[0] === "setMode" && command.length > 1) {
                list.screenState.launcher = false;
                Colours.setMode(command[1]);
            } else {
                list.screenState.launcher = false;
                if (!SleepGuard.run(command) && !SessionManager.exec(command))
                    Quickshell.execDetached(root.runnable(command));
            }
        }
    }
}
