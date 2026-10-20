import QtQuick
import qs.drift
import qs.drift.components

// The top of a Control Center detail view: ‹ back, the title, and whatever goes on the right (a toggle, a button).
Item {
    id: root

    property string title
    default property alias trailing: right.data

    implicitHeight: 44
    width: parent?.width ?? 0

    Rectangle {
        id: back

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: backArea.containsMouse ? Theme.tileHover : Theme.tile
        border.width: 1
        border.color: Theme.rimSoft

        Icon {
            anchors.centerIn: parent
            name: "chevron_left"
            size: 18
        }

        MouseArea {
            id: backArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: DriftState.ccPage = ""
        }
    }

    Label {
        anchors.left: back.right
        anchors.leftMargin: Theme.s3
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        size: Theme.heading
        font.weight: Font.DemiBold
    }

    Row {
        id: right

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.s3
    }
}
