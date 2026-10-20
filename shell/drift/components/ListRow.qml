import QtQuick
import qs.drift

// One row of a list (a network, a device, a search result): leading icon, title and subtitle, trailing text or widget.
// `current` is the keyboard selection (filled with the accent, as in the command bar); `hovered` lightens it.
Rectangle {
    id: root

    property string icon
    property string iconSource // an app icon image instead of a glyph
    property color iconTint: Theme.accent
    property string title
    property string subtitle
    property string trailing
    property bool current
    property bool checked // a check mark before the trailing text
    property bool busy // a spinner before the trailing text
    property bool dimmed
    property int rowHeight: 40
    property int titleSize: Theme.body
    default property alias trailingItems: trail.data
    readonly property alias hovered: area.containsMouse
    signal clicked

    implicitHeight: rowHeight
    radius: Theme.radiusRow
    color: current ? Theme.accent : area.containsMouse ? Theme.tileHover : "transparent"
    opacity: dimmed ? 0.5 : 1

    Behavior on color {
        ColorAnim { duration: Theme.fast }
    }

    Rectangle {
        id: badge

        visible: root.icon !== "" || root.iconSource !== ""
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 8
        color: root.iconSource !== "" ? "transparent" : root.current ? Qt.rgba(1, 1, 1, 0.22) : Qt.alpha(root.iconTint, 0.14)

        Icon {
            visible: root.iconSource === ""
            anchors.centerIn: parent
            name: root.icon
            size: 16
            color: root.current ? "#FFFFFF" : root.iconTint
        }

        Image {
            visible: root.iconSource !== ""
            anchors.fill: parent
            source: root.iconSource
            sourceSize: Qt.size(52, 52)
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }
    }

    Column {
        anchors.left: badge.visible ? badge.right : parent.left
        anchors.leftMargin: badge.visible ? 10 : 14
        anchors.right: trailRow.left
        anchors.rightMargin: Theme.s2
        anchors.verticalCenter: parent.verticalCenter

        Label {
            width: parent.width
            text: root.title
            size: root.titleSize
            color: root.current ? "#FFFFFF" : Theme.text
            font.weight: root.titleSize > Theme.body ? Font.DemiBold : Font.Medium
        }

        Label {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            size: Theme.small
            color: root.current ? Qt.rgba(1, 1, 1, 0.8) : Theme.textSecondary
        }
    }

    Row {
        id: trailRow

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Spinner {
            visible: root.busy
            anchors.verticalCenter: parent.verticalCenter
            size: 14
            color: root.current ? "#FFFFFF" : Theme.textSecondary
        }

        Icon {
            visible: root.checked
            anchors.verticalCenter: parent.verticalCenter
            name: "check"
            size: 16
            color: root.current ? "#FFFFFF" : Theme.accent
        }

        Label {
            visible: root.trailing !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.trailing
            size: Theme.small
            color: root.current ? Qt.rgba(1, 1, 1, 0.85) : Theme.textMuted
        }

        Row {
            id: trail

            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
