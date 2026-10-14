pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Jellyface.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// A to-do list on the desktop: type a task and press Enter, click the circle to tick it off, the bin to remove it.
// Saved in ~/.local/state/jellyface/todo.json.
GlassCard {
    id: root

    property var tasks: []
    readonly property int open: tasks.filter(t => !t.done).length

    implicitWidth: 380
    implicitHeight: Math.min(head.implicitHeight + list.contentHeight + field.implicitHeight + Tokens.padding.extraLargeIncreased * 2 + Tokens.spacing.large * 2, 520)

    function save(): void {
        file.setText(JSON.stringify(tasks));
    }

    function add(text: string): void {
        const t = text.trim();
        if (!t)
            return;
        tasks = [...tasks, {
                text: t,
                done: false
            }];
        save();
    }

    function toggle(i: int): void {
        tasks = tasks.map((t, k) => k === i ? {
                text: t.text,
                done: !t.done
            } : t);
        save();
    }

    function remove(i: int): void {
        tasks = tasks.filter((t, k) => k !== i);
        save();
    }

    FileView {
        id: file

        path: `${Paths.state}/todo.json`
        printErrors: false
        onLoaded: {
            try {
                root.tasks = JSON.parse(text());
            } catch (e) {
                console.warn("todo.json is not valid JSON:", e);
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLargeIncreased
        spacing: Tokens.spacing.large

        Row {
            id: head

            width: parent.width
            spacing: Tokens.spacing.medium

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "checklist"
                color: Colours.palette.m3primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "To-do"
                font: Tokens.font.title.medium
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.tasks.length === 0 ? "" : root.open === 0 ? "all done" : `${root.open} left`
                color: Colours.palette.m3outline
            }
        }

        ListView {
            id: list

            width: parent.width
            height: Math.min(contentHeight, 340)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.tasks

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 40

                MaterialIcon {
                    id: box

                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.done ? "check_circle" : "radio_button_unchecked"
                    fill: row.modelData.done ? 1 : 0
                    color: row.modelData.done ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle(row.index)
                    }
                }

                StyledText {
                    id: label

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: box.right
                    anchors.right: bin.left
                    anchors.leftMargin: Tokens.spacing.medium
                    text: row.modelData.text
                    elide: Text.ElideRight
                    color: row.modelData.done ? Colours.palette.m3outline : Colours.palette.m3onSurface

                    // a done task is struck through
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(label.implicitWidth, label.width)
                        height: 1.5
                        color: Colours.palette.m3outline
                        visible: row.modelData.done
                    }
                }

                MaterialIcon {
                    id: bin

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: "delete"
                    color: Colours.palette.m3outline
                    opacity: rowHover.hovered ? 1 : 0

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.remove(row.index)
                    }
                }

                // the bin shows while the pointer is anywhere on the row
                HoverHandler {
                    id: rowHover
                }
            }
        }

        StyledRect {
            id: field

            width: parent.width
            implicitHeight: 44
            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3onSurface, 0.1)

            MaterialIcon {
                id: plus

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.medium
                text: "add"
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: plus.right
                anchors.leftMargin: Tokens.spacing.small
                visible: input.text === ""
                text: "Add a task"
                color: Colours.palette.m3outline
            }

            TextInput {
                id: input

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: plus.right
                anchors.right: parent.right
                anchors.leftMargin: Tokens.spacing.small
                anchors.rightMargin: Tokens.padding.large
                clip: true
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary
                font: Tokens.font.body.medium
                selectByMouse: true
                onAccepted: {
                    root.add(text);
                    clear();
                }
            }
        }
    }
}
