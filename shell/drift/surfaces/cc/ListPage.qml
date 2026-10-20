import QtQuick
import qs.drift
import qs.drift.components

// A detail view that is mostly a list: keeps a keyboard selection (`current`) that Control Center moves with the
// arrows; Enter calls `activate(current)`. Long lists scroll. Give each row objectName "row<index>" so the
// selection can scroll into view.
Item {
    id: root

    property int current: -1
    property int count: 0
    property int maxListHeight: 360
    property alias header: headerSlot.data
    default property alias rows: column.data
    property alias footer: footerSlot.data
    signal activate(int index)

    implicitHeight: headerSlot.childrenRect.height + Math.min(column.implicitHeight, maxListHeight) + footerSlot.childrenRect.height + Theme.s2

    function move(d: int): void {
        if (count === 0)
            return;
        current = current < 0 ? (d > 0 ? 0 : count - 1) : Math.max(0, Math.min(count - 1, current + d));
        // rows are Repeater delegates named "row<index>"
        const row = Array.from(column.children).find(c => c.objectName === `row${current}`);
        if (row)
            flick.contentY = Math.max(0, Math.min(row.y - (flick.height - row.height) / 2, flick.contentHeight - flick.height));
    }

    function enter(): void {
        if (current >= 0)
            activate(current);
    }

    Column {
        id: headerSlot

        width: parent.width
    }

    Flickable {
        id: flick

        anchors.top: headerSlot.bottom
        anchors.topMargin: Theme.s1
        width: parent.width
        height: Math.min(column.implicitHeight, root.maxListHeight)
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            Anim { duration: Theme.fast }
        }

        Column {
            id: column

            width: parent.width
            spacing: 2
        }
    }

    Column {
        id: footerSlot

        anchors.top: flick.bottom
        anchors.topMargin: Theme.s2
        width: parent.width
    }
}
