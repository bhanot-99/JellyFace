import QtQuick
import Quickshell
import qs.drift
import qs.drift.components

// A preview of the lock screen (`jellyface ipc drift open lockpreview`, or Appearance), without locking anything: no
// password is taken. Any key or click closes it.
Surface {
    id: root

    name: "lockpreview"
    anchors.fill: parent
    rise: 0

    Keys.onPressed: e => {
        DriftState.close();
        e.accepted = true;
    }

    LockScreen {
        anchors.fill: parent
        shown: root.progress
        pam: null
    }

    MouseArea {
        anchors.fill: parent
        onClicked: DriftState.close()
    }

    Pill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        color: Theme.sheet

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "visibility"
            size: 15
            color: Theme.accent
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "Lock screen preview · any key closes"
            size: Theme.small
            font.weight: Font.Medium
        }
    }
}
