pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Jellyface
import qs.services
import qs.quill
import qs.quill.components

// Notifications as glass cards at the top right, under the bar (newest on top, at most four), plus JellyFace's own
// short notices ("Do Not Disturb on", "Now playing") as small pills. Hovering a card keeps it; click runs its action,
// × dismisses it. Do Not Disturb, Deep Focus and an open Control Center (which lists them) hold them back.
Scope {
    id: root

    readonly property bool quiet: Notifs.dnd || DeepFocus.active || QuillState.open === "cc"
    readonly property var cards: quiet ? [] : [...Notifs.popups].reverse().slice(0, 4)
    readonly property var notices: [...Toaster.toasts].filter(t => !t.closed).slice(-2)

    PanelWindow {
        id: win

        screen: Quickshell.screens[0]
        visible: root.cards.length > 0 || root.notices.length > 0
        WlrLayershell.namespace: "jellyface-quill-toasts"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        anchors.right: true
        margins.top: 10
        margins.right: 10
        implicitWidth: 380
        implicitHeight: stack.implicitHeight + 40
        color: "transparent"
        mask: Region {
            item: stack
        }

        Column {
            id: stack

            width: 360
            spacing: 8

            Repeater {
                model: root.notices

                Glass {
                    id: notice

                    required property var modelData

                    width: Math.min(360, row.implicitWidth + 32)
                    height: 44
                    radius: 22
                    color: Theme.sheet

                    Row {
                        id: row

                        anchors.centerIn: parent
                        spacing: 10

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: notice.modelData.icon || "info"
                            size: 17
                            color: Theme.accent
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: notice.modelData.title + (notice.modelData.message ? ` — ${notice.modelData.message}` : "")
                            size: Theme.small
                            width: Math.min(implicitWidth, 290)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: notice.modelData.close()
                    }
                }
            }

            Repeater {
                model: root.cards

                Glass {
                    id: card

                    required property var modelData

                    width: 360
                    height: body.implicitHeight
                    radius: 20
                    color: Theme.sheet
                    opacity: 0
                    x: 30

                    Component.onCompleted: {
                        opacity = 1;
                        x = 0;
                    }
                    // a card that leaves while hovered must not keep its notification locked open
                    Component.onDestruction: modelData?.unlock(card)

                    Behavior on opacity {
                        Anim {}
                    }
                    Behavior on x {
                        Anim { duration: Theme.slow }
                    }

                    HoverHandler {
                        onHoveredChanged: hovered ? card.modelData.lock(card) : card.modelData.unlock(card)
                    }

                    NotificationCard {
                        id: body

                        width: parent.width
                        toast: true
                        notif: card.modelData
                        onOpened: {
                            const n = card.modelData;
                            const a = n.actions?.find(a => a.identifier === "default") ?? (n.actions?.length === 1 ? n.actions[0] : null);
                            a?.invoke();
                            n.close();
                        }
                    }
                }
            }
        }
    }
}
