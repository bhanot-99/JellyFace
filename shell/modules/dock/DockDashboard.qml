pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils
import "components"

StyledRect {
    id: root

    required property var dock
    signal requestHide()

    color: Glass.enabled ? Glass.smoke : Colours.tPalette.m3surfaceContainer
    radius: 28
    border.width: Glass.enabled ? 1 : 0
    border.color: Glass.enabled ? Glass.rim : "transparent"

    implicitWidth: 1060
    implicitHeight: 660

    // Categorize dock apps into the 3 groups
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        // 1. Top Header Bar
        DashboardHeader {
            Layout.fillWidth: true
            onRequestHide: root.requestHide()
        }

        // 2. Top Row: 3 App Category Cards
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 136
            spacing: Tokens.spacing.small

            AppCategoryCard {
                Layout.fillWidth: true
                dock: root.dock
                title: Tr.tr("Work & Dev")
                categoryIcon: "code"
                accentColor: Colours.palette.m3primary
                appsList: root.categorizedApps.work
            }

            AppCategoryCard {
                Layout.fillWidth: true
                dock: root.dock
                title: Tr.tr("AI & Web Services")
                categoryIcon: "psychology"
                accentColor: Colours.palette.m3tertiary
                appsList: root.categorizedApps.ai
            }

            AppCategoryCard {
                Layout.fillWidth: true
                dock: root.dock
                title: Tr.tr("Media & Tools")
                categoryIcon: "apps"
                accentColor: Colours.palette.m3secondary
                appsList: root.categorizedApps.media
            }
        }

        // 3. Middle / Bottom Grid: System Stats (Left 62%) and Right Stack (Profile + Notifs + Emails 38%)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            // Left Section: System Stats Card
            SystemStatsCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 640
            }

            // Right Section: Stacked Profile, Notifications & Emails Cards
            ColumnLayout {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                ProfileCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 104
                }

                NotificationsCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 154
                }

                EmailsCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 164
                }
            }
        }
    }
}
