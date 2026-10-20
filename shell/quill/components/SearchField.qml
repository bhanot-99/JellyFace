import QtQuick
import qs.quill

// The command bar's search line: a magnifier, the text, a soft placeholder.
Item {
    id: root

    property alias text: input.text
    property string placeholder: "Type to search"
    property int size: Theme.heading
    readonly property alias input: input
    // ←/→ also navigate while nothing is typed (a horizontal list, like the clipboard)
    property bool horizontal
    signal accepted
    signal escaped
    signal navigate(int delta) // up / down arrows (and left / right when horizontal)
    signal removeRequested // Delete with nothing typed
    signal pinRequested // Ctrl+P

    implicitHeight: 48

    Icon {
        id: glass

        anchors.left: parent.left
        anchors.leftMargin: Theme.s4
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 20
        color: Theme.textSecondary
    }

    TextInput {
        id: input

        anchors.left: glass.right
        anchors.leftMargin: Theme.s3
        anchors.right: parent.right
        anchors.rightMargin: Theme.s4
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font
        font.pixelSize: root.size
        color: Theme.text
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.text
        cursorVisible: activeFocus
        clip: true

        Keys.onEscapePressed: root.escaped()
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onUpPressed: root.navigate(-1)
        Keys.onDownPressed: root.navigate(1)
        Keys.onTabPressed: root.navigate(1)
        Keys.onBacktabPressed: root.navigate(-1)
        Keys.onPressed: e => {
            if (root.horizontal && text === "" && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) {
                root.navigate(e.key === Qt.Key_Left ? -1 : 1);
                e.accepted = true;
            } else if (e.key === Qt.Key_Delete && text === "") {
                root.removeRequested();
                e.accepted = true;
            } else if (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier)) {
                root.pinRequested();
                e.accepted = true;
            }
        }

        Label {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            size: root.size
            muted: true
        }
    }
}
