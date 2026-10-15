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
    property real radius: Tokens.rounding.extraLarge

    readonly property alias surface: surface
    default property alias content: contentContainer.data

    property bool isResizing: false
    readonly property real maxDragX: parent ? Math.max(0, parent.width - root.width) : 3840
    readonly property real maxDragY: parent ? Math.max(0, parent.height - root.height) : 2160
    readonly property bool isDragging: cardDragArea.drag.active || tagMouse.drag.active

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

    // Main Card Surface: Bound to dynamic Glass.qml engine (Luminous GlassCardBase over backdrop)
    Rectangle {
        id: surface

        anchors.fill: parent
        radius: root.radius

        // Translucent liquid glass card base over compositor blur
        color: Glass.enabled ? Glass.standalone(Glass.glassCardBase) : Colours.tPalette.m3surfaceContainer

        border.width: 1
        border.color: !DashboardState.isLocked
            ? (cardDragArea.containsMouse || tagMouse.containsMouse || root.isDragging ? Glass.glassBorderHover : Qt.rgba(1.0, 1.0, 1.0, 0.32))
            : Glass.glassBorder

        Behavior on border.color {
            CAnim {
                duration: 150
            }
        }

        Behavior on color {
            CAnim {
                duration: 200
            }
        }

        // Tactile Spring & Organic Physics deformation on card during freeform drag
        scale: root.isDragging ? 0.985 : 1.0
        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        // Edit Mode Freeform Drag Handler: Underneath contentContainer, catches drags on card surface
        MouseArea {
            id: cardDragArea

            anchors.fill: parent
            enabled: !DashboardState.isLocked
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            propagateComposedEvents: true
            z: 2

            drag.target: root
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: root.maxDragX
            drag.maximumY: root.maxDragY
            drag.threshold: 8

            onPressed: mouse => {
                mouse.accepted = false; // Allow children to handle clicks first
            }

            onReleased: {
                root.x = Math.round(root.x / 16) * 16;
                root.y = Math.round(root.y / 16) * 16;
                DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
            }

            onCanceled: {
                root.x = Math.round(root.x / 16) * 16;
                root.y = Math.round(root.y / 16) * 16;
                DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
            }
        }

        // Content Container with generous padding
        Item {
            id: contentContainer

            anchors.fill: parent
            anchors.margins: root.contentPadding
            z: 10
        }

        // Edit Mode: Sleek Embossed Glass Drag Handle Pill (Hidden when locked)
        Rectangle {
            id: tagLabelBox

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.topMargin: -13
            implicitWidth: tagLabelRow.implicitWidth + 18
            implicitHeight: 26
            radius: Tokens.rounding.small
            color: tagMouse.pressed ? Glass.glassPillHover : (tagMouse.containsMouse ? Glass.glassElevatedTile : Glass.glassCardBase)
            border.width: 1
            border.color: Glass.glassActivePill
            visible: !DashboardState.isLocked
            z: 50

            Row {
                id: tagLabelRow
                anchors.centerIn: parent
                spacing: 5

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "drag_indicator"
                    color: Glass.textPrimary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title || root.cardId
                    font: Tokens.font.label.small
                    color: Glass.textPrimary
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
                drag.maximumX: root.maxDragX
                drag.maximumY: root.maxDragY
                drag.threshold: 0

                onReleased: {
                    root.x = Math.round(root.x / 16) * 16;
                    root.y = Math.round(root.y / 16) * 16;
                    DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                }

                onCanceled: {
                    root.x = Math.round(root.x / 16) * 16;
                    root.y = Math.round(root.y / 16) * 16;
                    DashboardState.setCardGeometry(root.cardId, root.x, root.y, root.width, root.height);
                }
            }
        }

        // Edit Mode: Tactile Glass Corner Resize Handle (Hidden when locked)
        Rectangle {
            id: resizeGrip

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 4
            anchors.bottomMargin: 4
            implicitWidth: 28
            implicitHeight: 28
            radius: Tokens.rounding.small
            color: resizeMouse.containsMouse || root.isResizing ? Glass.glassPillHover : Glass.glassElevatedTile
            border.width: 1
            border.color: resizeMouse.containsMouse || root.isResizing ? Glass.glassActivePill : Glass.glassBorder
            visible: root.canResize && !DashboardState.isLocked
            z: 60

            MaterialIcon {
                anchors.centerIn: parent
                text: "south_east"
                color: Glass.textPrimary
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
