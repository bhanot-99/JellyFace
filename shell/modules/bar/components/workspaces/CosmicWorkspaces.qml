import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Workspace switcher backed by COSMIC's real workspaces
StyledRect {
    id: root

    required property var screen
    required property bool fullscreen

    readonly property int cell: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: col.implicitHeight + Tokens.padding.extraSmall * 2
    visible: !fullscreen

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Column {
        id: col

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: CosmicWs.list

            StyledRect {
                id: item

                required property var modelData

                width: root.cell
                height: root.cell
                radius: Tokens.rounding.full
                color: modelData.active ? Colours.palette.m3primary : (modelData.urgent ? Colours.palette.m3error : "transparent")

                StyledText {
                    anchors.centerIn: parent
                    text: item.modelData.name
                    color: item.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CosmicWs.activate(item.modelData.i)
                }
            }
        }
    }
}
