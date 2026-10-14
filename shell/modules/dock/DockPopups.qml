pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// The dock's menus and dialogs, in one full-screen overlay while any of them is open: a click outside or Escape
// closes it. "app" = a tile's menu, "dock" = the dock's own menu, "addApp" = pick installed apps, "addWeb" = a web app.
Scope {
    id: root

    required property var dock

    function close(): void {
        dock.popup = "";
    }

    LazyLoader {
        active: root.dock.popup !== ""

        StyledWindow {
            id: win

            screen: Quickshell.screens[0]
            name: "dock-menu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.close()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.close()
            }

            Loader {
                anchors.fill: parent
                sourceComponent: root.dock.popup === "addApp" ? addApp : root.dock.popup === "addWeb" ? addWeb : menu
            }
        }
    }

    // --- menus ------------------------------------------------------------------------------------------------------
    Component {
        id: menu

        Item {
            id: menuRoot

            readonly property int index: root.dock.popupIndex
            readonly property var app: root.dock.popup === "app" ? root.dock.appAt(index) : null
            readonly property var wins: app ? root.dock.windowsOf(app) : []
            readonly property string label: app ? (app.name ?? DesktopEntries.heuristicLookup(app.id ?? "")?.name ?? app.id ?? "") : Tr.tr("Dock")

            StyledRect {
                id: card

                x: Math.max(12, Math.min(menuRoot.width - width - 12, root.dock.popupAnchor.x - width / 2))
                y: Math.max(12, root.dock.popupAnchor.y - height - 12)
                implicitWidth: 248
                implicitHeight: col.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainer
                transformOrigin: Item.Bottom

                // a quick pop: grow from the dock upwards
                scale: 0.92
                opacity: 0
                Component.onCompleted: {
                    scale = 1;
                    opacity = 1;
                }

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
                Behavior on opacity {
                    Anim {}
                }

                MouseArea {
                    anchors.fill: parent    // clicks on the card itself do not close it
                }

                ColumnLayout {
                    id: col

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.medium
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: Tokens.padding.medium
                        Layout.bottomMargin: Tokens.padding.small
                        text: menuRoot.label
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                        elide: Text.ElideRight
                    }

                    Row {
                        visible: !!menuRoot.app
                        icon: menuRoot.wins.length > 0 ? "add_box" : "open_in_new"
                        text: menuRoot.wins.length > 0 ? Tr.tr("New window") : Tr.tr("Open")
                        onActivated: {
                            root.dock.launch(menuRoot.app);
                            root.close();
                        }
                    }
                    Row {
                        visible: menuRoot.wins.length > 0
                        icon: "close"
                        text: menuRoot.wins.length > 1 ? Tr.tr("Close %1 windows").arg(menuRoot.wins.length) : Tr.tr("Close window")
                        onActivated: {
                            root.dock.closeAll(menuRoot.app);
                            root.close();
                        }
                    }
                    Row {
                        visible: !!menuRoot.app && menuRoot.index > 0
                        icon: "arrow_back"
                        text: Tr.tr("Move left")
                        onActivated: {
                            root.dock.move(menuRoot.index, menuRoot.index - 1);
                            root.close();
                        }
                    }
                    Row {
                        visible: !!menuRoot.app && menuRoot.index < root.dock.count - 1
                        icon: "arrow_forward"
                        text: Tr.tr("Move right")
                        onActivated: {
                            root.dock.move(menuRoot.index, menuRoot.index + 1);
                            root.close();
                        }
                    }
                    Row {
                        visible: !!menuRoot.app
                        icon: "delete"
                        text: Tr.tr("Remove from dock")
                        danger: true
                        onActivated: {
                            root.dock.remove(menuRoot.index);
                            root.close();
                        }
                    }

                    StyledRect {
                        visible: !!menuRoot.app
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        implicitHeight: 1
                        color: Colours.palette.m3outlineVariant
                    }

                    Row {
                        icon: "apps"
                        text: Tr.tr("Add app…")
                        onActivated: root.dock.popup = "addApp"
                    }
                    Row {
                        icon: "language"
                        text: Tr.tr("Add web app…")
                        onActivated: root.dock.popup = "addWeb"
                    }
                }
            }
        }
    }

    // --- add installed apps ---------------------------------------------------------------------------------------
    Component {
        id: addApp

        Item {
            Dialog {
                id: dlg

                readonly property var shown: {
                    const q = search.text.trim().toLowerCase();
                    const all = [...DesktopEntries.applications.values].filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name));
                    return q ? all.filter(a => a.name.toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q) || a.id.toLowerCase().includes(q)) : all;
                }

                title: Tr.tr("Add apps to the dock")
                subtitle: Tr.tr("Click to add; you can add several. Esc or Done when finished.")
                width: 520
                height: Math.min(parent.height - 160, 620)

                SearchBar {
                    id: search

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Search apps")
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    Keys.onReturnPressed: {
                        const a = dlg.shown[list.currentIndex];
                        if (a)
                            root.dock.add({id: a.id});
                    }
                    onTextChanged: list.currentIndex = 0
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: dlg.shown
                    highlightMoveDuration: 0

                    delegate: StyledRect {
                        id: entryRow

                        required property var modelData
                        required property int index
                        readonly property bool added: root.dock.has({id: modelData.id})

                        width: list.width
                        implicitHeight: 48
                        radius: Tokens.rounding.medium
                        color: ListView.isCurrentItem ? Colours.palette.m3secondaryContainer : "transparent"

                        StateLayer {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Colours.palette.m3onSurface
                            onClicked: {
                                list.currentIndex = entryRow.index;
                                if (!entryRow.added)
                                    root.dock.add({id: entryRow.modelData.id});
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.rightMargin: Tokens.padding.large
                            spacing: Tokens.spacing.medium

                            IconImage {
                                implicitSize: 30
                                source: Quickshell.iconPath(entryRow.modelData.icon, "application-x-executable")
                                asynchronous: true
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: entryRow.modelData.name
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurface
                            }
                            MaterialIcon {
                                text: entryRow.added ? "check_circle" : "add_circle"
                                color: entryRow.added ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fill: entryRow.added ? 1 : 0
                            }
                        }
                    }
                }

                Buttons {
                    okText: Tr.tr("Done")
                    onOk: root.close()
                }
            }
        }
    }

    // --- add a web app -------------------------------------------------------------------------------------------
    Component {
        id: addWeb

        Item {
            Dialog {
                id: web

                // "github.com/foo" -> "https://github.com/foo"; null if it does not look like a web address
                readonly property string url: {
                    let u = address.text.trim();
                    if (!u)
                        return "";
                    if (!/^https?:\/\//i.test(u))
                        u = "https://" + u;
                    return /^https?:\/\/[^\s\/.]+\.[^\s\/]+(\/\S*)?$/i.test(u) ? u : "";
                }
                readonly property string host: url ? url.split("/")[2].replace(/^www\./, "") : ""
                readonly property string appName: name.text.trim() || (host ? host.split(".")[0].charAt(0).toUpperCase() + host.split(".")[0].slice(1) : "")

                function submit(): void {
                    if (!url)
                        return;
                    // opens as its own app window in the first Chromium-type browser found, else in the default browser
                    const q = "'" + url.replace(/'/g, "'\\''") + "'";
                    const command = `for b in brave-browser google-chrome chromium chromium-browser microsoft-edge vivaldi; do command -v "$b" >/dev/null && exec "$b" --app=${q}; done; exec xdg-open ${q}`;
                    root.dock.add({name: appName, command: command, match: host});
                    root.close();
                }

                title: Tr.tr("Add a web app")
                subtitle: Tr.tr("It opens in its own window, like an app.")
                width: 460
                height: implicitHeight

                StyledTextField {
                    id: address

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Address, e.g. web.whatsapp.com")
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: web.submit()
                }
                StyledTextField {
                    id: name

                    Layout.fillWidth: true
                    placeholderText: web.appName ? Tr.tr("Name (%1)").arg(web.appName) : Tr.tr("Name (optional)")
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: web.submit()
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: address.text.trim().length > 0 && !web.url
                    text: Tr.tr("That does not look like a web address")
                    color: Colours.palette.m3error
                    font: Tokens.font.body.small
                }

                Buttons {
                    okText: Tr.tr("Add")
                    okEnabled: !!web.url
                    onOk: web.submit()
                }
            }
        }
    }

    // --- building blocks ------------------------------------------------------------------------------------------
    component Row: StyledRect {
        id: row

        property string icon
        property string text
        property bool danger

        signal activated

        Layout.fillWidth: true
        implicitHeight: 40
        radius: Tokens.rounding.medium
        color: "transparent"

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            color: row.danger ? Colours.palette.m3error : Colours.palette.m3onSurface
            onClicked: row.activated()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: row.icon
                color: row.danger ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                text: row.text
                color: row.danger ? Colours.palette.m3error : Colours.palette.m3onSurface
                elide: Text.ElideRight
            }
        }
    }

    component Dialog: StyledRect {
        id: dialog

        property string title
        property string subtitle
        default property alias body: content.data

        anchors.centerIn: parent
        implicitHeight: content.implicitHeight + Tokens.padding.extraLarge * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainer

        scale: 0.94
        opacity: 0
        Component.onCompleted: {
            scale = 1;
            opacity = 1;
        }

        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
        Behavior on opacity {
            Anim {}
        }

        MouseArea {
            anchors.fill: parent    // clicks inside the dialog do not close it
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge
            spacing: Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                text: dialog.title
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.medium
            }
            StyledText {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.small
                text: dialog.subtitle
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.Wrap
            }
        }
    }

    component Buttons: RowLayout {
        id: buttons

        property string okText
        property bool okEnabled: true

        signal ok

        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        spacing: Tokens.spacing.medium

        Item {
            Layout.fillWidth: true
        }

        StyledRect {
            implicitWidth: cancelText.implicitWidth + Tokens.padding.extraLarge * 2
            implicitHeight: 40
            radius: Tokens.rounding.full
            color: "transparent"

            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                color: Colours.palette.m3onSurface
                onClicked: root.close()
            }
            StyledText {
                id: cancelText

                anchors.centerIn: parent
                text: Tr.tr("Cancel")
                color: Colours.palette.m3primary
            }
        }

        StyledRect {
            implicitWidth: okLabel.implicitWidth + Tokens.padding.extraLarge * 2
            implicitHeight: 40
            radius: Tokens.rounding.full
            color: buttons.okEnabled ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
            opacity: buttons.okEnabled ? 1 : 0.6

            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                disabled: !buttons.okEnabled
                color: Colours.palette.m3onPrimary
                onClicked: buttons.ok()
            }
            StyledText {
                id: okLabel

                anchors.centerIn: parent
                text: buttons.okText
                color: buttons.okEnabled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
