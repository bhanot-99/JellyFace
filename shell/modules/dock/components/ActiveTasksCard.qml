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

    cardId: "activeTasks"
    title: Tr.tr("Active Tasks")
    minW: 360
    minH: 52
    canResize: true
    contentPadding: 10

    RowLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            spacing: 4

            MaterialIcon {
                text: "select_window"
                color: Qt.rgba(1, 1, 1, 0.70)
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: "Active"
                font: Tokens.font.label.small
                color: Qt.rgba(1, 1, 1, 0.50)
            }
        }

        // Horizontal Task Strip with Smart Truncate
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                anchors.fill: parent
                contentWidth: windowPills.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: windowPills
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: CosmicWindows.windows

                        delegate: Rectangle {
                            id: winPill

                            required property var modelData
                            readonly property var win: modelData
                            readonly property bool isActive: win.id === CosmicWindows.activeId

                            implicitWidth: Math.min(180, winContent.implicitWidth + 14)
                            implicitHeight: 28
                            radius: 6
                            color: winHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : (isActive ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18) : Qt.rgba(1, 1, 1, 0.05))
                            border.width: 1
                            border.color: isActive ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.06)

                            RowLayout {
                                id: winContent
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: isActive ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.35)
                                }

                                StyledText {
                                    text: winPill.win?.title || winPill.win?.app_id || "Window"
                                    font: Tokens.font.label.small
                                    color: isActive ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.70)
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 140
                                }
                            }

                            HoverHandler {
                                id: winHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CosmicWindows.activate(winPill.win.id)
                            }
                        }
                    }

                    StyledText {
                        text: "No active application windows"
                        font: Tokens.font.label.small
                        color: Qt.rgba(1, 1, 1, 0.35)
                        visible: CosmicWindows.windows.length === 0
                    }
                }
            }
        }
    }
}
