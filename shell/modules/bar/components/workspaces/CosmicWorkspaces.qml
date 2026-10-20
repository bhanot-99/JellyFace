import QtQuick
import Jellyface.Config
import qs.components
import qs.services

// Workspace switcher backed by COSMIC's real workspaces
StyledRect {
    id: root

    required property var screen
    required property bool fullscreen   // unused: the whole bar folds away (hiding just this jolted the bar's layout)

    readonly property int cell: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: col.implicitHeight + Tokens.padding.extraSmall * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Column {
        id: col

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        // A count, not the list itself: the helper sends a new list on every switch, and a list model rebuilt every
        // pill each time (the highlight jumped instead of moving). Indexed, the pills stay and only their colours change.
        Repeater {
            model: CosmicWs.list.length

            StyledRect {
                id: item

                required property int index
                readonly property var modelData: CosmicWs.list[index] ?? ({})

                width: root.cell
                height: root.cell
                radius: Tokens.rounding.full
                color: modelData.active ? Colours.palette.m3primary : (modelData.urgent ? Colours.palette.m3error : "transparent")

                StyledText {
                    anchors.centerIn: parent
                    text: item.modelData.name ?? ""
                    color: item.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (item.modelData.i !== undefined) CosmicWs.activate(item.modelData.i)
                }
            }
        }
    }
}
