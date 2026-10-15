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

Rectangle {
    id: root

    required property var dock

    // Layered Glass Surface: Deep smoked acrylic container
    color: Qt.rgba(20 / 255, 22 / 255, 28 / 255, 0.72)
    radius: 24
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.08)

    // Top hairline specular light highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: parent.radius
        anchors.rightMargin: parent.radius
        height: 1
        color: Qt.rgba(255, 255, 255, 0.16)
        z: 2
    }

    implicitWidth: 1040
    implicitHeight: 620

    // Categorize dock apps into the 3 groups cleanly
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
        anchors.margins: 16
        spacing: 12

        // Top Header Row
        DashboardHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
        }

        // Main 2-Column Asymmetric Grid (64% / 36%) with 12px Gutter & Matching Bottom Bounds
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Left Column: App Trays + System Stats & Network
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 650
                spacing: 12

                // Top 3 App Trays
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    spacing: 10

                    AppCategoryCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        dock: root.dock
                        title: Tr.tr("Work & Dev")
                        categoryIcon: "code"
                        accentColor: "#38bdf8"
                        appsList: root.categorizedApps.work
                    }

                    AppCategoryCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        dock: root.dock
                        title: Tr.tr("AI & Web")
                        categoryIcon: "psychology"
                        accentColor: "#a855f7"
                        appsList: root.categorizedApps.ai
                    }

                    AppCategoryCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        dock: root.dock
                        title: Tr.tr("Media & Tools")
                        categoryIcon: "apps"
                        accentColor: "#34d399"
                        appsList: root.categorizedApps.media
                    }
                }

                // System Stats & Network Activity Card (Fills remaining height)
                SystemStatsCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }

            // Right Column: Profile + Live Notifications + Primary Mails
            ColumnLayout {
                Layout.preferredWidth: 350
                Layout.fillHeight: true
                spacing: 12

                // Profile Card ("Me")
                ProfileCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                }

                // Live Notifications (Adaptive collapsed micro-banner when empty)
                NotificationsCard {
                    Layout.fillWidth: true
                }

                // Primary Mails Feed (Fills remaining height with zero clipping)
                EmailsCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
