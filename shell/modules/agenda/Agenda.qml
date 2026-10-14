pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.utils

// Desktop Agenda card: today's and tomorrow's calendar events, on the Bottom layer (every window covers it).
// Settings: ~/.config/jellyface/desktop.json  { "agenda": { "enabled", "source": ".ics path or iCal URL", "days", "refreshMinutes" } }
// scripts/agenda.py reads the calendar and writes ~/.local/state/jellyface/agenda.json, which this card shows.
Scope {
    id: root

    property bool enabled: true
    property int refreshMinutes: 15
    property string state: "no-source"
    property string error: ""
    property var events: []
    property date now: new Date()

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/jellyface`

    function sameDay(iso: string, d: date): bool {
        const x = new Date(iso);
        return x.getFullYear() === d.getFullYear() && x.getMonth() === d.getMonth() && x.getDate() === d.getDate();
    }

    function dayEvents(offset: int): var {
        const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset);
        const next = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
        return events.filter(e => {
            const s = new Date(e.start), en = new Date(e.end);
            return s < next && en > d && !(en <= now && offset === 0);
        });
    }

    function timeText(e: var): string {
        if (e.allDay)
            return Tr.tr("All day");
        return Qt.formatTime(new Date(e.start), "hh:mm");
    }

    function isNow(e: var): bool {
        return !e.allDay && new Date(e.start) <= now && new Date(e.end) > now;
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.now = new Date()
    }

    Timer {
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        interval: Math.max(1, root.refreshMinutes) * 60000
        onTriggered: refresh.running = true
    }

    Process {
        id: refresh

        command: ["python3", Quickshell.shellPath("../scripts/agenda.py")]
    }

    FileView {
        path: `${Paths.config}/desktop.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const a = JSON.parse(text()).agenda ?? {};
                root.enabled = a.enabled ?? true;
                root.refreshMinutes = a.refreshMinutes ?? 15;
                refresh.running = true;
            } catch (e) {
                console.warn("desktop.json is not valid JSON:", e);
            }
        }
    }

    FileView {
        path: `${root.stateDir}/agenda.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.state = d.state ?? "no-source";
                root.error = d.error ?? "";
                root.events = d.events ?? [];
            } catch (e) {
                root.state = "error";
            }
        }
    }

    LazyLoader {
        active: root.enabled

        StyledWindow {
            id: win

            screen: Quickshell.screens[0]
            name: "agenda"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom

            anchors.top: true
            anchors.right: true
            margins.top: 28
            margins.right: 28
            implicitWidth: 340
            implicitHeight: card.implicitHeight

            StyledRect {
                id: card

                width: parent.width
                implicitHeight: col.implicitHeight + Tokens.padding.extraLarge * 2
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                ColumnLayout {
                    id: col

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    RowLayout {
                        Layout.fillWidth: true

                        MaterialIcon {
                            text: "event"
                            color: Colours.palette.m3primary
                            fill: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("Agenda")
                            font: Tokens.font.body.large
                        }

                        StyledText {
                            text: Qt.formatDate(root.now, "ddd d MMM")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.state !== "ok"
                        wrapMode: Text.Wrap
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        text: root.state === "error" ? Tr.tr("Could not read the calendar: %1").arg(root.error) : Tr.tr("No calendar yet. Set \"agenda.source\" in ~/.config/jellyface/desktop.json to a .ics file or your calendar's iCal URL.")
                    }

                    Repeater {
                        model: root.state === "ok" ? [0, 1] : []

                        ColumnLayout {
                            id: dayCol

                            required property int modelData
                            readonly property var list: root.dayEvents(modelData)

                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: dayCol.modelData === 0 ? Tr.tr("Today") : Tr.tr("Tomorrow")
                                color: Colours.palette.m3secondary
                                font: Tokens.font.body.medium
                            }

                            StyledText {
                                visible: dayCol.list.length === 0
                                text: Tr.tr("Nothing planned")
                                color: Colours.palette.m3outline
                                font: Tokens.font.body.small
                            }

                            Repeater {
                                model: dayCol.list.slice(0, 5)

                                StyledRect {
                                    id: row

                                    required property var modelData
                                    readonly property bool current: root.isNow(modelData)

                                    Layout.fillWidth: true
                                    implicitHeight: rowLayout.implicitHeight + Tokens.padding.small * 2
                                    radius: Tokens.rounding.large
                                    color: current ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                                    RowLayout {
                                        id: rowLayout

                                        anchors.fill: parent
                                        anchors.margins: Tokens.padding.small
                                        anchors.leftMargin: Tokens.padding.medium
                                        spacing: Tokens.spacing.medium

                                        StyledText {
                                            Layout.preferredWidth: 52
                                            text: root.timeText(row.modelData)
                                            color: row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                                            font: Tokens.font.mono.small
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: row.modelData.title
                                                elide: Text.ElideRight
                                                color: row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                                font: Tokens.font.body.small
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                visible: row.modelData.location !== ""
                                                text: row.modelData.location
                                                elide: Text.ElideRight
                                                color: Colours.palette.m3onSurfaceVariant
                                                font: Tokens.font.body.small
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
