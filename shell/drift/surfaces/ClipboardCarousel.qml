pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.drift
import qs.drift.components

// Clipboard history (Super+V): everything you copied as a fan of cards (text, links, colours, images), newest in the
// middle. ←/→ move, type to filter, Enter puts it back on the clipboard (then paste as usual), Delete removes it,
// Ctrl+P pins it (pinned entries are never trimmed). Content marked sensitive by a password manager is never stored.
Surface {
    id: root

    name: "clipboard"
    anchors.fill: parent

    property int current: 0
    readonly property string query: field.text.trim().toLowerCase()
    readonly property var items: Clipboard.entries.filter(e => !query || (e.text ?? "").toLowerCase().includes(query)).slice(0, 40)

    function kindOf(e: var): string {
        if (e.kind === "image")
            return "image";
        const t = (e.text ?? "").trim();
        if (/^(#[0-9a-f]{3,8}|rgba?\([\d\s.,%]+\)|hsla?\([\d\s.,%deg]+\))$/i.test(t))
            return "colour";
        if (/^(https?:\/\/|www\.)\S+$/i.test(t))
            return "link";
        // code: several lines that end like code, or start with a keyword or a shell prompt (prose with a ";" is text)
        const lines = t.split("\n");
        const codeish = lines.filter(l => /[;{}]\s*$|^\s*(def|fn|function|import|from|const|let|var|class|return|if|for)\b|^\s*(\$|#!|\/\/)/.test(l)).length;
        if (lines.length > 1 && codeish >= Math.max(2, lines.length * 0.3))
            return "code";
        return "text";
    }

    function use(i: int): void {
        const e = items[i];
        if (!e)
            return;
        Clipboard.copy(e);
        DriftState.close();
    }

    onActiveChanged: if (active) {
        field.text = "";
        current = 0;
        field.input.forceActiveFocus();
    }
    onQueryChanged: current = 0

    blur: Region {
        BlurRegion {
            pane: bar.body
        }
    }

    // ── the fan ──
    Item {
        id: fan

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 30
        width: parent.width
        height: 300

        Repeater {
            model: root.items

            Item {
                id: card

                required property var modelData
                required property int index
                readonly property int offset: index - root.current
                readonly property string kind: root.kindOf(modelData)
                readonly property bool centre: offset === 0

                visible: Math.abs(offset) <= 4
                width: 260
                height: 220
                x: fan.width / 2 - width / 2 + offset * 210 - Math.sign(offset) * Math.min(Math.abs(offset), 3) * 10
                y: 40 + Math.abs(offset) * 10
                z: 10 - Math.abs(offset)
                scale: centre ? 1.08 : 1 - Math.min(0.24, Math.abs(offset) * 0.08)
                opacity: (1 - Math.min(0.75, Math.abs(offset) * 0.22)) * root.progress
                rotation: offset * 3

                Behavior on x {
                    Anim { duration: Theme.normal }
                }
                Behavior on y {
                    Anim { duration: Theme.normal }
                }
                Behavior on scale {
                    Anim { duration: Theme.normal }
                }
                Behavior on rotation {
                    Anim { duration: Theme.normal }
                }

                Glass {
                    anchors.fill: parent
                    radius: 22
                    color: Theme.sheet
                    shadowStrength: card.centre ? 1.3 : 0.6

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: card.centre ? 2 : 0
                        border.color: Theme.accent
                    }

                    // kind + age
                    Row {
                        x: 16
                        y: 14
                        spacing: 6

                        Icon {
                            name: card.kind === "image" ? "image" : card.kind === "colour" ? "palette" : card.kind === "link" ? "link" : card.kind === "code" ? "code" : "notes"
                            size: 15
                            color: Theme.accent
                        }

                        Kicker {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.kind
                        }
                    }

                    Icon {
                        visible: card.modelData.pinned
                        x: parent.width - 30
                        y: 12
                        name: "push_pin"
                        size: 16
                        filled: true
                        color: Theme.accent
                    }

                    // the content
                    Item {
                        x: 16
                        y: 42
                        width: parent.width - 32
                        height: parent.height - 70

                        Rectangle {
                            visible: card.kind === "colour"
                            anchors.centerIn: parent
                            width: 92
                            height: 92
                            radius: 24
                            color: card.kind === "colour" ? card.modelData.text.trim() : "transparent"
                            border.width: 1
                            border.color: Theme.rimSoft
                        }

                        Image {
                            visible: card.kind === "image"
                            anchors.fill: parent
                            source: card.kind === "image" ? `file://${card.modelData.file}` : ""
                            sourceSize: Qt.size(520, 300)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {
                            visible: card.kind === "text" || card.kind === "link" || card.kind === "code"
                            anchors.fill: parent
                            text: (card.modelData.text ?? "").slice(0, 600)
                            wrapMode: card.kind === "code" ? Text.NoWrap : Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 7
                            clip: true
                            textFormat: Text.PlainText
                            font.family: card.kind === "code" ? Theme.mono : Theme.font
                            font.pixelSize: card.kind === "code" ? 11 : 13
                            color: card.kind === "link" ? Theme.accent : Theme.text
                        }
                    }

                    Label {
                        x: 16
                        y: parent.height - 24
                        width: parent.width - 32
                        text: card.kind === "colour" ? card.modelData.text.trim() : card.kind === "image" ? "Image" : `${(card.modelData.text ?? "").length} characters`
                        size: Theme.caption + 1
                        muted: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.centre ? root.use(card.index) : root.current = card.index
                    }
                }
            }
        }

        Label {
            visible: root.items.length === 0
            anchors.centerIn: parent
            text: Clipboard.entries.length === 0 ? "Nothing copied yet" : "Nothing matches"
            size: Theme.heading
            secondary: true
        }
    }

    // ── the search pill and keys ──
    Glass {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: fan.top
        anchors.bottomMargin: 10
        width: 520
        height: 54
        radius: 27
        color: Theme.sheet

        SearchField {
            id: field

            anchors.left: parent.left
            anchors.right: keys.left
            anchors.verticalCenter: parent.verticalCenter
            height: 50
            size: Theme.body + 1
            placeholder: "Everything you copied — type to filter"
            horizontal: true
            onAccepted: root.use(root.current)
            onEscaped: field.text ? field.text = "" : DriftState.close()
            onNavigate: d => root.current = Math.max(0, Math.min(root.items.length - 1, root.current + d))
            onRemoveRequested: {
                const e = root.items[root.current];
                if (e)
                    Clipboard.remove(e);
            }
            onPinRequested: {
                const e = root.items[root.current];
                if (e)
                    Clipboard.togglePin(e);
            }
        }

        Row {
            id: keys

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Keycap { key: "← →" }
            Keycap { key: "↵" }
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: fan.bottom
        anchors.topMargin: 6
        text: "Enter copies it back — then paste as usual · Delete removes · Ctrl+P pins"
        size: Theme.small
        muted: true
    }
}
