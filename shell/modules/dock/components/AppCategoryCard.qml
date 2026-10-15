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

StyledRect {
    id: root

    required property var dock
    required property string title
    required property string categoryIcon
    required property color accentColor
    property var appsList: []

    color: Glass.enabled ? Glass.mist : Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge
    implicitHeight: 140

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        // Card Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: Tokens.rounding.medium
                color: Qt.alpha(root.accentColor, Glass.enabled ? 0.25 : 0.15)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.categoryIcon
                    color: root.accentColor
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                text: root.title
                font: Tokens.font.title.small
                color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            StyledRect {
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: 20
                radius: Tokens.rounding.full
                color: Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHighest

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: `${root.appsList.length}`
                    font: Tokens.font.label.small
                    color: Glass.enabled ? Glass.haze : Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // App Icons Row / Flow
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
                    spacing: 8

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

                            implicitWidth: 44
                            implicitHeight: 56

                            StyledRect {
                                id: pill
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: Tokens.rounding.medium
                                color: tileHover.hovered ? (Glass.enabled ? Glass.frostHigh : Colours.palette.m3surfaceContainerHighest) : (tile.running ? (Glass.enabled ? Glass.frost : Colours.palette.m3surfaceContainerHigh) : "transparent")

                                Behavior on color {
                                    CAnim {}
                                }

                                scale: tileMouse.pressed ? 0.92 : (tileHover.hovered ? 1.08 : 1.0)
                                Behavior on scale {
                                    Anim {
                                        type: Anim.FastSpatial
                                    }
                                }

                                Loader {
                                    anchors.centerIn: parent
                                    width: 26
                                    height: 26
                                    active: tile.iconSource !== ""
                                    sourceComponent: Image {
                                        source: tile.iconSource
                                        sourceSize.width: 26
                                        sourceSize.height: 26
                                        smooth: true
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                Loader {
                                    anchors.centerIn: parent
                                    active: tile.iconSource === ""
                                    sourceComponent: MaterialIcon {
                                        text: tile.symbol || "apps"
                                        color: Glass.enabled ? Glass.ice : Colours.palette.m3primary
                                        fontStyle: Tokens.font.icon.medium
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
                                            root.dock.openPopup("app", tile.index, pill);
                                        } else {
                                            root.dock.open(tile.app);
                                        }
                                    }
                                }
                            }

                            // Running / Active indicator dot
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: tile.focused ? 12 : (tile.running ? 5 : 0)
                                height: 4
                                radius: 2
                                color: tile.focused ? (Glass.enabled ? Glass.ice : Colours.palette.m3primary) : root.accentColor
                                visible: tile.running

                                Behavior on width {
                                    Anim {
                                        type: Anim.FastSpatial
                                    }
                                }
                            }

                            // Tooltip on hover
                            StyledRect {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 6
                                z: 100
                                implicitWidth: tipText.implicitWidth + 12
                                implicitHeight: tipText.implicitHeight + 6
                                radius: Tokens.rounding.full
                                color: Glass.enabled ? Glass.sheet : Colours.palette.m3surfaceContainerHighest
                                visible: tileHover.hovered && !tileMouse.pressed

                                StyledText {
                                    id: tipText
                                    anchors.centerIn: parent
                                    text: tile.label
                                    font: Tokens.font.label.small
                                    color: Glass.enabled ? Glass.ice : Colours.palette.m3onSurface
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
