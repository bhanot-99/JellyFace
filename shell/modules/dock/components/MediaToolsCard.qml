pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils
import ".."

ModularCard {
    id: root

    required property var dock
    cardId: "mediaTools"
    title: Tr.tr("Media & Tools")
    minW: 160
    minH: 80
    canResize: true
    contentPadding: 8

    readonly property var appsList: {
        const list = [];
        for (let i = 0; i < root.dock.apps.count; i++) {
            const app = root.dock.appAt(i);
            if (!app)
                continue;
            const id = (app.id || "").toLowerCase();
            const name = (app.name || "").toLowerCase();
            const match = (app.match || "").toLowerCase();
            const full = `${id} ${name} ${match}`;

            if (!full.includes("claude") && !full.includes("chatgpt") && !full.includes("gemini") && !full.includes("openai") && !full.includes("brave") && !full.includes("pinterest") && !full.includes("code") && !full.includes("sublime") && !full.includes("term") && !full.includes("files") && !full.includes("obsidian") && !full.includes("github") && !full.includes("git")) {
                list.push(app);
            }
        }
        return list;
    }

    AppCategoryCard {
        anchors.fill: parent
        dock: root.dock
        title: Tr.tr("Media & Tools")
        categoryIcon: "apps"
        accentColor: "#34d399"
        appsList: root.appsList
    }
}
