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

    // Main Card Surface: Tactile Matte Slate-Titanium Skeuo-Modern Container (20px Superellipse)
    Rectangle {
        id: surface

        anchors.fill: parent
        radius: 20
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#f0373a42"
            }
            GradientStop {
                position: 1.0
                color: "#f026282e"
            }
        }
        border.width: 1
        border.color: !DashboardState.isLocked ? (cardDragArea.containsMouse || tagMouse.containsMouse || root.isDragging ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.18)) : Qt.rgba(1, 1, 1, 0.08)

        Behavior on border.color {
            CAnim {
                duration: 150
            }
        }

        // Tactile Top-Lit Bevel Specular Highlight (Hairline)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        // Tactile Bottom Recessed Edge (Shadow)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(0, 0, 0, 0.50)
        }

        // Edit Mode Freeform Drag Handler: Underneath contentContainer, catches drags on card surface
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

        // Content Container with generous padding
        Item {
            id: contentContainer

            anchors.fill: parent
            anchors.margins: root.contentPadding
            z: 10
        }

        // Edit Mode: Sleek Embossed Slate Drag Handle Pill (Replaces orange badge)
        Rectangle {
            id: tagLabelBox

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.topMargin: -13
            implicitWidth: tagLabelRow.implicitWidth + 18
            implicitHeight: 26
            radius: 8
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: tagMouse.pressed ? "#2e3138" : (tagMouse.containsMouse ? "#444852" : "#373a42")
                }
                GradientStop {
                    position: 1.0
                    color: tagMouse.pressed ? "#222428" : (tagMouse.containsMouse ? "#31343b" : "#26282e")
                }
            }
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)
            visible: !DashboardState.isLocked
            z: 50

            // Top-lit micro-highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.radius
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(1, 1, 1, 0.28)
            }

            Row {
                id: tagLabelRow
                anchors.centerIn: parent
                spacing: 5

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "drag_indicator"
                    color: "#E5E7EB"
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title || root.cardId
                    font: Tokens.font.label.small
                    color: "#E5E7EB"
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

        // Edit Mode: Tactile Corner Resize Handle (Hidden when locked)
        Rectangle {
            id: resizeGrip

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 4
            anchors.bottomMargin: 4
            implicitWidth: 28
            implicitHeight: 28
            radius: 8
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: resizeMouse.containsMouse || root.isResizing ? "#4f5460" : "#373a42"
                }
                GradientStop {
                    position: 1.0
                    color: resizeMouse.containsMouse || root.isResizing ? "#383b44" : "#26282e"
                }
            }
            border.width: 1
            border.color: resizeMouse.containsMouse || root.isResizing ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.12)
            visible: root.canResize && !DashboardState.isLocked
            z: 60

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.radius
                anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(1, 1, 1, 0.25)
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "south_east"
                color: "#E5E7EB"
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
