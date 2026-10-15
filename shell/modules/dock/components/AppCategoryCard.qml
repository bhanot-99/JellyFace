pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services
import qs.utils

Rectangle {
    id: root

    required property var dock
    required property string title
    required property string categoryIcon
    required property color accentColor
    property var appsList: []

    function dockIndexOf(app): int {
        if (!app)
            return -1;
        for (let i = 0; i < root.dock.apps.count; i++) {
            const a = root.dock.appAt(i);
            if (a && ((app.id && a.id === app.id) || (app.name && a.name === app.name)))
                return i;
        }
        return -1;
    }

    color: "transparent"
    radius: 12
    border.width: 0

    implicitHeight: 88
    Layout.minimumHeight: 88

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 6

        // Card Header: Title + Baseline-aligned Count Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                implicitWidth: 22
                implicitHeight: 22
                radius: 6
                color: Qt.alpha(root.accentColor, 0.18)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.categoryIcon
                    color: root.accentColor
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: root.title
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: Qt.rgba(1, 1, 1, 0.95)
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                implicitWidth: countText.implicitWidth + 8
                implicitHeight: 18
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.06)
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: `${root.appsList.length}`
                    font: Tokens.font.label.small
                    color: Qt.rgba(1, 1, 1, 0.60)
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // App Icons Row: Uniform 32x32px hit-targets, 8px squircle radii, fixed 6px gap
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                anchors.fill: parent
                contentWidth: appsRow.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: appsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: root.appsList

                        delegate: Item {
                            id: tile

                            required property var modelData
                            required property int index
                            readonly property var app: modelData
                            readonly property var entry: app?.id ? DesktopEntries.heuristicLookup(app.id) : null
                            readonly property var windows: root.dock.windowsOf(app)
                            readonly property bool running: windows.length > 0
                            readonly property bool focused: windows.some(w => w.id === CosmicWindows.activeId)
                            readonly property string label: app?.name ?? entry?.name ?? app?.id ?? ""
                            readonly property string symbol: app?.symbol || root.dock.symbolFor(`${app?.name ?? ""} ${app?.match ?? ""} ${app?.id ?? ""} ${entry?.name ?? ""}`) || Icons.getAppCategoryIcon(app?.id ?? "", "apps")

                            readonly property string iconSource: {
                                const i = app?.icon || entry?.icon || app?.id || "";
                                if (i.startsWith("/"))
                                    return `file://${i}`;
                                if (i.includes("/"))
                                    return `file://${Quickshell.shellPath(`../${i}`)}`;
                                return Quickshell.iconPath(i, true) || `file://${Paths.home}/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/${i}.png` || Quickshell.iconPath("application-x-executable") || "";
                            }

                            implicitWidth: 36
                            implicitHeight: 44

                            Rectangle {
                                id: pill
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: 8
                                color: tileHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : (tile.running ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.width: 1
                                border.color: tile.focused ? Qt.rgba(255, 255, 255, 0.25) : (tileHover.hovered ? Qt.rgba(255, 255, 255, 0.10) : "transparent")

                                Behavior on color {
                                    CAnim {
                                        duration: 150
                                    }
                                }

                                scale: tileMouse.pressed ? 0.92 : (tileHover.hovered ? 1.05 : 1.0)
                                Behavior on scale {
                                    Anim {
                                        type: Anim.FastSpatial
                                    }
                                }

                                Loader {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    active: tile.iconSource !== ""
                                    sourceComponent: Image {
                                        source: tile.iconSource
                                        sourceSize.width: 20
                                        sourceSize.height: 20
                                        smooth: true
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                Loader {
                                    anchors.centerIn: parent
                                    active: tile.iconSource === ""
                                    sourceComponent: MaterialIcon {
                                        text: tile.symbol || "apps"
                                        color: Qt.rgba(1, 1, 1, 0.90)
                                        fontStyle: Tokens.font.icon.small
                                    }
                                }

                                HoverHandler {
                                    id: tileHover
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            const dockIdx = root.dockIndexOf(tile.app);
                                            if (dockIdx >= 0)
                                                root.dock.openPopup("app", dockIdx, pill);
                                        } else {
                                            root.dock.open(tile.app);
                                        }
                                    }
                                }
                            }

                            // Running / Active indicator micro-dot
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: tile.focused ? 10 : (tile.running ? 4 : 0)
                                height: 3
                                radius: 1.5
                                color: tile.focused ? "#38bdf8" : "#34d399"
                                visible: tile.running

                                Behavior on width {
                                    Anim {
                                        type: Anim.FastSpatial
                                    }
                                }
                            }

                            // Clean Tooltip on hover
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 4
                                z: 100
                                implicitWidth: tipText.implicitWidth + 10
                                implicitHeight: tipText.implicitHeight + 4
                                radius: 6
                                color: Qt.rgba(20, 22, 28, 0.92)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.12)
                                visible: tileHover.hovered && !tileMouse.pressed

                                StyledText {
                                    id: tipText
                                    anchors.centerIn: parent
                                    text: tile.label
                                    font: Tokens.font.label.small
                                    color: Qt.rgba(1, 1, 1, 0.95)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
