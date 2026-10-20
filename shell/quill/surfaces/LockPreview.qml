import QtQuick
import qs.quill
import qs.quill.components

// A preview of the lock screen (`jellyface ipc quill open lockpreview`, or Appearance), without locking anything: no
// password is taken. Any key or click closes it. Built only while it shows: the lock screen measures CPU, memory and
// storage, which the desktop must not keep doing for a preview nobody looks at.
Surface {
    id: root

    name: "lockpreview"
    anchors.fill: parent
    rise: 0

    Keys.onPressed: e => {
        QuillState.close();
        e.accepted = true;
    }

    Loader {
        anchors.fill: parent
        active: root.visible

        sourceComponent: LockScreen {
            shown: root.progress
            pam: null
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: QuillState.close()
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
