import QtQuick
import Quickshell.Widgets
import qs.drift

// One notification: app icon (or its image), app · age, summary, two lines of body, × to dismiss.
// Used in Control Center and as a toast.
Rectangle {
    id: root

    property var notif
    property bool current
    property bool toast // a toast has its own glass, so no tile behind it
    signal opened

    implicitHeight: Math.max(64, content.implicitHeight + 20)
    radius: Theme.radiusRow + 2
    color: toast ? "transparent" : current ? Theme.accentSoft : area.containsMouse ? Theme.tileHover : Theme.tile
    border.width: toast ? 0 : 1
    border.color: current ? Theme.accent : Theme.rimSoft

    Behavior on color {
        ColorAnim { duration: Theme.fast }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }

    Rectangle {
        id: badge

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        width: 34
        height: 34
        radius: 10
        color: Theme.accentSoft
        clip: true

        Icon {
            visible: !img.visible && !appIcon.visible
            anchors.centerIn: parent
            name: "notifications"
            size: 18
            color: Theme.accent
        }

        IconImage {
            id: appIcon

            anchors.centerIn: parent
            implicitSize: 24
            visible: !img.visible && status === Image.Ready
            source: root.notif?.appIcon ? (root.notif.appIcon.startsWith("/") ? `file://${root.notif.appIcon}` : `image://icon/${root.notif.appIcon}`) : ""
            asynchronous: true
        }

        Image {
            id: img

            anchors.fill: parent
            visible: status === Image.Ready
            source: root.notif?.image ?? ""
            sourceSize: Qt.size(68, 68)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        id: content

        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: close.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 10
        spacing: 1

        Label {
            width: parent.width
            text: `${root.notif?.appName || "Notification"} · ${root.notif?.timeStr ?? ""}`
            size: Theme.caption + 1
            muted: true
        }

        Label {
            width: parent.width
            text: root.notif?.summary ?? ""
            font.weight: Font.DemiBold
        }

        Label {
            visible: text !== ""
            width: parent.width
            text: (root.notif?.body ?? "").replace(/<[^>]*>/g, "")
            size: Theme.small
            secondary: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            textFormat: Text.PlainText
        }
    }

    Rectangle {
        id: close

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        width: 24
        height: 24
        radius: 12
        opacity: area.containsMouse || closeArea.containsMouse || root.current ? 1 : 0
        color: closeArea.containsMouse ? Theme.tileHover : "transparent"

        Behavior on opacity {
            Anim { duration: Theme.fast }
        }

        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 15
            color: Theme.textSecondary
        }

        MouseArea {
            id: closeArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notif?.close()
        }
    }
}
