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
    property real maxW: 1920
    property real maxH: 1400
    property bool canResize: false
    property bool defaultVisible: true
    property real contentPadding: 16

    default property alias content: contentContainer.data

    property bool isDragging: false
    property bool isResizing: false

    visible: DashboardState.isCardVisible(root.cardId, root.defaultVisible)

    // Load initial layout geometry from persisted state or defaults
    Component.onCompleted: {
        const c = DashboardState.getCard(root.cardId, root.defaultX, root.defaultY, root.defaultW, root.defaultH);
        root.x = c.x;
        root.y = c.y;
        root.width = Math.max(root.minW, Math.min(root.maxW, c.width));
        root.height = Math.max(root.minH, Math.min(root.maxH, c.height));
    }

    // Sync state changes when not actively dragging or resizing
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

    // Main Card Surface: Layered Frosted Glass Backdrop
    Rectangle {
        id: surface

        anchors.fill: parent
        radius: 16
        color: Qt.rgba(22 / 255, 25 / 255, 35 / 255, 0.72)
        border.width: 1
        border.color: !DashboardState.isLocked ? (cardDragArea.containsMouse || tagMouse.containsMouse || root.isDragging ? "#f59e0b" : Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.50)) : Qt.rgba(255, 255, 255, 0.08)

        Behavior on border.color {
            CAnim {
                duration: 150
            }
        }

        // Top hairline specular highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(255, 255, 255, 0.16)
        }

        // Edit Mode Freeform Drag Handler: Underneath contentContainer, catches drags on card surface/empty areas
        MouseArea {
            id: cardDragArea

            anchors.fill: parent
            enabled: !DashboardState.isLocked
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            z: 2

            drag.target: root
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: root.parent ? Math.max(0, root.parent.width - root.width) : 3840
            drag.maximumY: root.parent ? Math.max(0, root.parent.height - root.height) : 2160
            drag.threshold: 0

            onPressed: {
                root.isDragging = true;
            }

            onReleased: {
                root.isDragging = false;
                root.x = Math.round(root.x / 16) * 16;
                root.y = Math.round(root.y / 16) * 16;
                DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
            }

            onCanceled: {
                if (root.isDragging) {
                    root.isDragging = false;
                    root.x = Math.round(root.x / 16) * 16;
                    root.y = Math.round(root.y / 16) * 16;
                    DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                }
            }
        }

        // Content Container with generous padding (higher z so buttons and inputs work)
        Item {
            id: contentContainer

            anchors.fill: parent
            anchors.margins: root.contentPadding
            z: 10
        }

        // Edit Mode: Top-Left Card Tag Handle Pill with Direct Drag Target
        Rectangle {
            id: tagLabelBox

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.topMargin: -14
            implicitWidth: tagLabelRow.implicitWidth + 16
            implicitHeight: 26
            radius: 7
            color: tagMouse.pressed ? "#d97706" : (tagMouse.containsMouse ? "#fbbf24" : "#f59e0b")
            border.width: 1
            border.color: "#ffffff"
            visible: !DashboardState.isLocked
            z: 50

            Row {
                id: tagLabelRow
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

            MouseArea {
                id: tagMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                acceptedButtons: Qt.LeftButton
                preventStealing: true

                drag.target: root
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: root.parent ? Math.max(0, root.parent.width - root.width) : 3840
                drag.maximumY: root.parent ? Math.max(0, root.parent.height - root.height) : 2160
                drag.threshold: 0

                onPressed: {
                    root.isDragging = true;
                }

                onReleased: {
                    root.isDragging = false;
                    root.x = Math.round(root.x / 16) * 16;
                    root.y = Math.round(root.y / 16) * 16;
                    DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                }

                onCanceled: {
                    if (root.isDragging) {
                        root.isDragging = false;
                        root.x = Math.round(root.x / 16) * 16;
                        root.y = Math.round(root.y / 16) * 16;
                        DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                    }
                }
            }
        }

        // Edit Mode: High-Hit Target Corner Resize Handle (32x32px)
        Rectangle {
            id: resizeGrip

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitWidth: 32
            implicitHeight: 32
            radius: 8
            color: resizeMouse.containsMouse || root.isResizing ? "#f59e0b" : Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.40)
            border.width: 1
            border.color: resizeMouse.containsMouse || root.isResizing ? "#ffffff" : Qt.rgba(255, 255, 255, 0.20)
            visible: root.canResize && !DashboardState.isLocked
            z: 60

            MaterialIcon {
                anchors.centerIn: parent
                text: "south_east"
                color: resizeMouse.containsMouse || root.isResizing ? "#000000" : "#ffffff"
                fontStyle: Tokens.font.icon.small
            }

            MouseArea {
                id: resizeMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
                acceptedButtons: Qt.LeftButton
                preventStealing: true

                property real startParentX: 0
                property real startParentY: 0
                property real startW: 0
                property real startH: 0

                onPressed: mouse => {
                    root.isResizing = true;
                    startW = root.width;
                    startH = root.height;
                    const p = resizeMouse.mapToItem(root.parent, mouse.x, mouse.y);
                    startParentX = p.x;
                    startParentY = p.y;
                }

                onPositionChanged: mouse => {
                    if (root.isResizing) {
                        const p = resizeMouse.mapToItem(root.parent, mouse.x, mouse.y);
                        const deltaX = p.x - startParentX;
                        const deltaY = p.y - startParentY;
                        const snappedW = Math.round((startW + deltaX) / 16) * 16;
                        const snappedH = Math.round((startH + deltaY) / 16) * 16;
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

                onCanceled: {
                    if (root.isResizing) {
                        root.isResizing = false;
                        DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                    }
                }
            }
        }
    }
}
