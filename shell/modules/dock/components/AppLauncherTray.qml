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
    cardId: "appTray"
    title: Tr.tr("App Launcher Tray")
    minW: 480
    minH: 104
    canResize: true
    contentPadding: 14

    readonly property var categorizedApps: {
        const work = [];
        const ai = [];
        const media = [];
        for (let i = 0; i < root.dock.apps.count; i++) {
            const app = root.dock.appAt(i);
            if (!app)
                continue;
            const id = (app.id || "").toLowerCase();
            const name = (app.name || "").toLowerCase();
            const match = (app.match || "").toLowerCase();
            const full = `${id} ${name} ${match}`;

            if (full.includes("claude") || full.includes("chatgpt") || full.includes("gemini") || full.includes("openai") || full.includes("brave")) {
                ai.push(app);
            } else if (full.includes("code") || full.includes("sublime") || full.includes("term") || full.includes("files") || full.includes("obsidian") || full.includes("github") || full.includes("git")) {
                work.push(app);
            } else {
                media.push(app);
            }
        }
        return {
            work: work,
            ai: ai,
            media: media
        };
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        AppCategoryCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            dock: root.dock
            title: Tr.tr("Work & Dev")
            categoryIcon: "code"
            accentColor: "#38bdf8"
            appsList: root.categorizedApps.work
        }

        AppCategoryCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            dock: root.dock
            title: Tr.tr("AI & Web")
            categoryIcon: "psychology"
            accentColor: "#a855f7"
            appsList: root.categorizedApps.ai
        }

        AppCategoryCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            dock: root.dock
            title: Tr.tr("Media & Tools")
            categoryIcon: "apps"
            accentColor: "#34d399"
            appsList: root.categorizedApps.media
        }
    }
}
