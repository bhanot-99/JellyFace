import QtQuick
import Jellyface.Config
import qs.components
import qs.services

// Bell button that toggles the notification sidebar (the click-outside-to-close grab is Hyprland-only)
Item {
    id: root

    required property ScreenState screenState

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    StateLayer {
        // Cursed workaround to make the height larger than the parent
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: root.screenState.sidebar = !root.screenState.sidebar
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: root.screenState.sidebar ? "notifications_active" : "notifications"
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }
}
