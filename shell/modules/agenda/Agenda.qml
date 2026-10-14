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

    // The first event that has not finished yet (today first, then tomorrow)
    readonly property var nextEvent: events.find(e => new Date(e.end) > now && !(e.allDay && new Date(e.end) <= now)) ?? null

    function untilText(e: var): string {
        if (!e)
            return "";
        if (isNow(e))
            return Tr.tr("Now, until %1").arg(Qt.formatTime(new Date(e.end), "hh:mm"));
        if (e.allDay)
            return Tr.tr("All day");
        const mins = Math.round((new Date(e.start) - now) / 60000);
        if (mins < 60)
            return Tr.tr("In %1 min").arg(Math.max(mins, 1));
        const h = Math.floor(mins / 60);
        if (h < 24)
            return Tr.tr("In %1 h %2 min").arg(h).arg(mins % 60);
        return Qt.formatDateTime(new Date(e.start), "ddd hh:mm");
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
            implicitWidth: 360
            implicitHeight: layout.implicitHeight

            // Bento layout like the dashboard: separate tiles with different corner shapes, no backing card
            ColumnLayout {
                id: layout

                width: parent.width
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    // Date tile: a big day number, one corner much rounder than the rest
                    StyledRect {
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 112
                        color: Colours.palette.m3primaryContainer
                        topLeftRadius: 56
                        topRightRadius: Tokens.rounding.large
                        bottomLeftRadius: Tokens.rounding.large
                        bottomRightRadius: Tokens.rounding.extraLarge

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: -4

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(root.now, "d")
                                color: Colours.palette.m3onPrimaryContainer
                                font.pointSize: 30
                                font.weight: Font.Bold
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(root.now, "MMM").toUpperCase()
                                color: Colours.palette.m3onPrimaryContainer
                                font: Tokens.font.body.medium
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(root.now, "ddd")
                                color: Colours.palette.m3onPrimaryContainer
                                opacity: 0.7
                                font: Tokens.font.body.small
                            }
                        }
                    }

                    // Next-up tile
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 112
                        color: root.nextEvent && root.isNow(root.nextEvent) ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
                        topLeftRadius: Tokens.rounding.large
                        topRightRadius: 56
                        bottomLeftRadius: Tokens.rounding.extraLarge
                        bottomRightRadius: Tokens.rounding.large

                        readonly property color fg: root.nextEvent && root.isNow(root.nextEvent) ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSecondaryContainer

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.extraLarge * 1.5
                            spacing: 2

                            StyledText {
                                text: root.state !== "ok" ? Tr.tr("Agenda") : root.nextEvent ? Tr.tr("Next up") : Tr.tr("All clear")
                                color: parent.parent.fg
                                opacity: 0.7
                                font: Tokens.font.body.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: root.state !== "ok" ? (root.state === "error" ? Tr.tr("Calendar unreachable") : Tr.tr("No calendar yet")) : root.nextEvent ? root.nextEvent.title : Tr.tr("Nothing planned")
                                color: parent.parent.fg
                                font: Tokens.font.body.large
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.state === "ok" && !!root.nextEvent
                                text: root.untilText(root.nextEvent) + (root.nextEvent?.location ? "  ·  " + root.nextEvent.location : "")
                                color: parent.parent.fg
                                elide: Text.ElideRight
                                font: Tokens.font.mono.small
                            }
                        }
                    }
                }

                // Setup / error hint
                StyledRect {
                    Layout.fillWidth: true
                    visible: root.state !== "ok"
                    implicitHeight: hint.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.extraLarge
                    color: Colours.tPalette.m3surfaceContainer

                    StyledText {
                        id: hint

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        wrapMode: Text.Wrap
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        text: root.state === "error" ? Tr.tr("Could not read the calendar: %1").arg(root.error) : Tr.tr("Connect Google Calendar: run  jellyface agenda set <secret iCal address>")
                    }
                }

                // Day tiles
                Repeater {
                    model: root.state === "ok" ? [0, 1] : []

                    StyledRect {
                        id: dayTile

                        required property int modelData
                        readonly property var list: root.dayEvents(modelData)

                        Layout.fillWidth: true
                        implicitHeight: dayCol.implicitHeight + Tokens.padding.large * 2
                        color: Colours.tPalette.m3surfaceContainer
                        topLeftRadius: modelData === 0 ? Tokens.rounding.extraLarge : Tokens.rounding.large
                        topRightRadius: modelData === 0 ? Tokens.rounding.large : Tokens.rounding.extraLarge
                        bottomLeftRadius: modelData === 0 ? Tokens.rounding.large : Tokens.rounding.extraLarge
                        bottomRightRadius: modelData === 0 ? Tokens.rounding.extraLarge : Tokens.rounding.large

                        ColumnLayout {
                            id: dayCol

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.spacing.small

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    Layout.fillWidth: true
                                    text: dayTile.modelData === 0 ? Tr.tr("Today") : Tr.tr("Tomorrow")
                                    color: dayTile.modelData === 0 ? Colours.palette.m3primary : Colours.palette.m3tertiary
                                    font: Tokens.font.body.medium
                                }

                                // Event-count pill
                                StyledRect {
                                    implicitWidth: count.implicitWidth + Tokens.padding.medium * 2
                                    implicitHeight: count.implicitHeight + Tokens.padding.small
                                    radius: Tokens.rounding.full
                                    color: dayTile.modelData === 0 ? Colours.palette.m3primary : Colours.palette.m3tertiary

                                    StyledText {
                                        id: count

                                        anchors.centerIn: parent
                                        text: dayTile.list.length
                                        color: dayTile.modelData === 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onTertiary
                                        font: Tokens.font.body.small
                                    }
                                }
                            }

                            StyledText {
                                visible: dayTile.list.length === 0
                                text: Tr.tr("Nothing planned")
                                color: Colours.palette.m3outline
                                font: Tokens.font.body.small
                            }

                            Repeater {
                                model: dayTile.list.slice(0, 4)

                                RowLayout {
                                    id: row

                                    required property var modelData
                                    readonly property bool current: root.isNow(modelData)

                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.medium

                                    // Timeline dot
                                    StyledRect {
                                        implicitWidth: 10
                                        implicitHeight: 10
                                        radius: Tokens.rounding.full
                                        color: row.current ? Colours.palette.m3tertiary : dayTile.modelData === 0 ? Colours.palette.m3primary : Colours.palette.m3outline
                                    }

                                    StyledText {
                                        Layout.preferredWidth: 50
                                        text: root.timeText(row.modelData)
                                        color: Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.mono.small
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: row.modelData.title
                                        elide: Text.ElideRight
                                        color: row.current ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
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
