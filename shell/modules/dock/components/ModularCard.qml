pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Jellyface.Config
import qs.components
import qs.services
import ".."

Item {
    id: root

    required property string cardId
    property string title: ""
    property real defaultX: 100
    property real defaultY: 100
    property real defaultW: 400
    property real defaultH: 200
    property real minW: 160
    property real minH: 44
    property real maxW: 1600
    property real maxH: 1200
    property bool canResize: false
    property bool defaultVisible: true
    property real contentPadding: 18

    default property alias content: contentContainer.data

    property bool isDragging: false
    property bool isResizing: false

    visible: DashboardState.isCardVisible(root.cardId, root.defaultVisible)

    // Load initial layout geometry
    Component.onCompleted: {
        const c = DashboardState.getCard(root.cardId, root.defaultX, root.defaultY, root.defaultW, root.defaultH);
        root.x = c.x;
        root.y = c.y;
        root.width = Math.max(root.minW, Math.min(root.maxW, c.width));
        root.height = Math.max(root.minH, Math.min(root.maxH, c.height));
    }

    // Sync external state changes when not actively interacting
    Connections {
        function onLayoutChanged(): void {
            if (!root.isDragging && !root.isResizing) {
                const c = DashboardState.getCard(root.cardId, root.defaultX, root.defaultY, root.defaultW, root.defaultH);
                root.x = c.x;
                root.y = c.y;
                root.width = Math.max(root.minW, Math.min(root.maxW, c.width));
                root.height = Math.max(root.minH, Math.min(root.maxH, c.height));
            }
        }

        target: DashboardState
    }

    // Main Card Surface: Layered Frosted Glass
    Rectangle {
        id: surface

        anchors.fill: parent
        radius: 16
        color: Qt.rgba(22 / 255, 25 / 255, 35 / 255, 0.72)
        border.width: 1
        border.color: !DashboardState.isLocked ? (cardDragArea.containsMouse || root.isDragging ? "#f59e0b" : Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.45)) : Qt.rgba(255, 255, 255, 0.08)

        Behavior on border.color {
            CAnim {
                duration: 150
            }
        }

        // Top specular hairline highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(255, 255, 255, 0.16)
        }

        // Content Container with generous 18px-22px padding
        Item {
            id: contentContainer

            anchors.fill: parent
            anchors.margins: root.contentPadding
        }

        // Edit Mode: Top-Left Card Tag Label
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: -10
            implicitWidth: tagLabel.implicitWidth + 14
            implicitHeight: 20
            radius: 6
            color: "#f59e0b"
            visible: !DashboardState.isLocked
            z: 20

            Row {
                id: tagLabel
                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "drag_indicator"
                    color: "#000000"
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title || root.cardId
                    font: Tokens.font.label.small
                    color: "#000000"
                }
            }
        }

        // Edit Mode: Corner Resize Handle
        Rectangle {
            id: resizeGrip

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitWidth: 20
            implicitHeight: 20
            radius: 4
            color: resizeMouse.containsMouse || root.isResizing ? "#f59e0b" : Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.35)
            visible: root.canResize && !DashboardState.isLocked
            z: 25

            MaterialIcon {
                anchors.centerIn: parent
                text: "south_east"
                color: resizeMouse.containsMouse || root.isResizing ? "#000000" : "#f59e0b"
                fontStyle: Tokens.font.icon.small
            }

            MouseArea {
                id: resizeMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
                acceptedButtons: Qt.LeftButton

                property real startW
                property real startH
                property real startX
                property real startY

                onPressed: mouse => {
                    root.isResizing = true;
                    startW = root.width;
                    startH = root.height;
                    startX = mouse.x;
                    startY = mouse.y;
                }

                onPositionChanged: mouse => {
                    if (root.isResizing) {
                        const rawW = startW + (mouse.x - startX);
                        const rawH = startH + (mouse.y - startY);
                        // 16px magnetic snap-to-grid
                        const snappedW = Math.round(rawW / 16) * 16;
                        const snappedH = Math.round(rawH / 16) * 16;
                        root.width = Math.max(root.minW, Math.min(root.maxW, snappedW));
                        root.height = Math.max(root.minH, Math.min(root.maxH, snappedH));
                    }
                }

                onReleased: {
                    if (root.isResizing) {
                        root.isResizing = false;
                        DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                    }
                }
            }
        }

        // Edit Mode Drag Handler (over surface when unlocked)
        MouseArea {
            id: cardDragArea

            anchors.fill: parent
            enabled: !DashboardState.isLocked
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            z: 10

            property real grabOffsetX
            property real grabOffsetY

            onPressed: mouse => {
                root.isDragging = true;
                grabOffsetX = mouse.x;
                grabOffsetY = mouse.y;
            }

            onPositionChanged: mouse => {
                if (root.isDragging) {
                    const rawX = root.x + (mouse.x - grabOffsetX);
                    const rawY = root.y + (mouse.y - grabOffsetY);
                    // 16px magnetic snap-to-grid
                    const snappedX = Math.round(rawX / 16) * 16;
                    const snappedY = Math.round(rawY / 16) * 16;
                    const maxX = root.parent ? Math.max(0, root.parent.width - root.width) : 3840;
                    const maxY = root.parent ? Math.max(0, root.parent.height - root.height) : 2160;
                    root.x = Math.max(0, Math.min(maxX, snappedX));
                    root.y = Math.max(0, Math.min(maxY, snappedY));
                }
            }

            onReleased: {
                if (root.isDragging) {
                    root.isDragging = false;
                    DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                }
            }
        }
    }
}
