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
    cardId: "aiWeb"
    title: Tr.tr("AI & Web")
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

            if (full.includes("claude") || full.includes("chatgpt") || full.includes("gemini") || full.includes("openai") || full.includes("brave") || full.includes("pinterest")) {
                list.push(app);
            }
        }
        return list;
    }

    AppCategoryCard {
        anchors.fill: parent
        dock: root.dock
        title: Tr.tr("AI & Web")
        categoryIcon: "psychology"
        accentColor: "#FFFFFF"
        appsList: root.appsList
    }
}
