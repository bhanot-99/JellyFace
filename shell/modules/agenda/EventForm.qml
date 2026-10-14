pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// "New event" form (jellyface ipc agenda add, or the + buttons on the dashboard calendar and the Agenda card).
// Enter saves, Esc closes. Leave the times empty (or switch on All day) for an all-day event.
Scope {
    LazyLoader {
        active: AgendaEvents.formOpen

        StyledWindow {
            id: win

            screen: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
            name: "agenda-form"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            BackgroundEffect.blurRegion: Glass.enabled ? sheetBlur : null

            GlassRegion {
                id: sheetBlur

                pane: sheet
            }

            MouseArea {
                anchors.fill: parent
                onClicked: AgendaEvents.formOpen = false
            }

            Item {
                id: form

                property string error
                readonly property bool allDay: allDaySwitch.checked

                function save(): void {
                    const t = title.text.trim();
                    if (!t) {
                        error = Tr.tr("Give the event a title");
                        return;
                    }
                    if (!/^\d{4}-\d{2}-\d{2}$/.test(day.text.trim())) {
                        error = Tr.tr("Date must look like 2026-12-31");
                        return;
                    }
                    const timeOk = v => /^([01]?\d|2[0-3]):[0-5]\d$/.test(v);
                    let s = "", e = "";
                    if (!allDay) {
                        s = start.text.trim();
                        e = end.text.trim();
                        if (!timeOk(s) || (e && !timeOk(e))) {
                            error = Tr.tr("Times must look like 14:30");
                            return;
                        }
                        if (s.length === 4)
                            s = "0" + s;
                        if (e.length === 4)
                            e = "0" + e;
                    }
                    AgendaEvents.add(t, day.text.trim(), s, e, place.text.trim());
                    AgendaEvents.formOpen = false;
                }

                function setDay(offset: int): void {
                    const d = new Date();
                    d.setDate(d.getDate() + offset);
                    day.text = Qt.formatDate(d, "yyyy-MM-dd");
                }

                anchors.centerIn: parent
                width: 460
                height: col.implicitHeight

                GlassSheet {
                    id: sheet
                }

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: col

                    width: parent.width
                    spacing: Tokens.spacing.medium

                    // Header tile
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        color: Colours.palette.m3primaryContainer
                        topLeftRadius: 32
                        topRightRadius: Tokens.rounding.large
                        bottomLeftRadius: Tokens.rounding.large
                        bottomRightRadius: 32

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.extraLarge
                            anchors.rightMargin: Tokens.padding.extraLarge
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "event_available"
                                color: Colours.palette.m3onPrimaryContainer
                                fill: 1
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Tr.tr("New event")
                                color: Colours.palette.m3onPrimaryContainer
                                font: Tokens.font.title.small
                            }

                            StyledText {
                                text: Tr.tr("Saved on this computer")
                                color: Colours.palette.m3onPrimaryContainer
                                opacity: 0.7
                                font: Tokens.font.body.small
                            }
                        }
                    }

                    // Fields tile
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: fields.implicitHeight + Tokens.padding.extraLarge * 2
                        color: Colours.palette.m3surface
                        radius: Tokens.rounding.extraLarge
                        topRightRadius: Tokens.rounding.small

                        ColumnLayout {
                            id: fields

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.extraLarge
                            spacing: Tokens.spacing.medium

                            StyledTextField {
                                id: title

                                Layout.fillWidth: true
                                placeholderText: Tr.tr("Title")
                                Component.onCompleted: forceActiveFocus()
                                Keys.onEscapePressed: AgendaEvents.formOpen = false
                                Keys.onReturnPressed: form.save()
                                onTextChanged: form.error = ""
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.medium

                                StyledTextField {
                                    id: day

                                    Layout.fillWidth: true
                                    placeholderText: Tr.tr("Date (YYYY-MM-DD)")
                                    text: AgendaEvents.presetDate
                                    Keys.onEscapePressed: AgendaEvents.formOpen = false
                                    Keys.onReturnPressed: form.save()
                                    onTextChanged: form.error = ""
                                }

                                Chip {
                                    label: Tr.tr("Today")
                                    onTriggered: form.setDay(0)
                                }

                                Chip {
                                    label: Tr.tr("Tomorrow")
                                    onTriggered: form.setDay(1)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.medium

                                StyledTextField {
                                    id: start

                                    Layout.fillWidth: true
                                    enabled: !form.allDay
                                    opacity: enabled ? 1 : 0.4
                                    placeholderText: Tr.tr("Start (HH:MM)")
                                    Keys.onEscapePressed: AgendaEvents.formOpen = false
                                    Keys.onReturnPressed: form.save()
                                    onTextChanged: form.error = ""
                                }

                                StyledTextField {
                                    id: end

                                    Layout.fillWidth: true
                                    enabled: !form.allDay
                                    opacity: enabled ? 1 : 0.4
                                    placeholderText: Tr.tr("End (optional)")
                                    Keys.onEscapePressed: AgendaEvents.formOpen = false
                                    Keys.onReturnPressed: form.save()
                                    onTextChanged: form.error = ""
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.medium

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Tr.tr("All day")
                                    font: Tokens.font.body.medium
                                }

                                StyledSwitch {
                                    id: allDaySwitch
                                }
                            }

                            StyledTextField {
                                id: place

                                Layout.fillWidth: true
                                placeholderText: Tr.tr("Place (optional)")
                                Keys.onEscapePressed: AgendaEvents.formOpen = false
                                Keys.onReturnPressed: form.save()
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: form.error !== ""
                                text: form.error
                                color: Colours.palette.m3error
                                font: Tokens.font.body.small
                            }
                        }
                    }

                    // Buttons tiles
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            Layout.preferredWidth: 130
                            implicitHeight: 52
                            color: Colours.palette.m3surfaceContainerHigh
                            radius: 26
                            bottomLeftRadius: Tokens.rounding.small

                            StateLayer {
                                onClicked: AgendaEvents.formOpen = false
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: Tr.tr("Cancel")
                                font: Tokens.font.body.medium
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 52
                            color: Colours.palette.m3primary
                            radius: 26
                            bottomRightRadius: Tokens.rounding.small

                            StateLayer {
                                color: Colours.palette.m3onPrimary
                                onClicked: form.save()
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: Tr.tr("Add event")
                                color: Colours.palette.m3onPrimary
                                font: Tokens.font.body.medium
                            }
                        }
                    }
                }
            }
        }
    }

    component Chip: StyledRect {
        id: chip

        required property string label

        signal triggered

        implicitWidth: chipText.implicitWidth + Tokens.padding.large * 2
        implicitHeight: 40
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer

        StateLayer {
            color: Colours.palette.m3onSecondaryContainer
            onClicked: chip.triggered()
        }

        StyledText {
            id: chipText

            anchors.centerIn: parent
            text: chip.label
            color: Colours.palette.m3onSecondaryContainer
            font: Tokens.font.body.small
        }
    }
}
