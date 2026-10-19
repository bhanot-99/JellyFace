pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import M3Shapes
import Jellyface.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

CustomMouseArea {
    id: root

    required property ScreenState screenState

    property date currentDate: screenState.dashboardDate
    readonly property int currMonth: currentDate.getMonth()
    readonly property int currYear: currentDate.getFullYear()
    readonly property int nonAnimCurrMonth: screenState.dashboardDate.getMonth()
    readonly property int nonAnimCurrYear: screenState.dashboardDate.getFullYear()

    readonly property int animDirection: screenState.dashboardDate > currentDate ? -1 : 1
    property real animTranslate
    property real animOpacity: 1

    // { "YYYY-MM-DD": [{ title, holiday }] } written by scripts/agenda.py (your calendars, local events, public holidays)
    property var dayEvents: ({})
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/jellyface`

    FileView {
        path: `${root.stateDir}/calendar.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.dayEvents = JSON.parse(text());
            } catch (e) {
                root.dayEvents = ({});
            }
        }
    }

    function onWheel(event: WheelEvent): void {
        if (event.angleDelta.y > 0)
            screenState.dashboardDate = new Date(nonAnimCurrYear, nonAnimCurrMonth - 1, 1);
        else if (event.angleDelta.y < 0)
            screenState.dashboardDate = new Date(nonAnimCurrYear, nonAnimCurrMonth + 1, 1);
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: inner.implicitHeight + inner.anchors.margins * 2

    acceptedButtons: Qt.MiddleButton
    onClicked: root.screenState.dashboardDate = new Date()

    Anim {
        id: trOutAnim

        running: false
        target: root
        property: "animTranslate"
        to: root.Tokens.padding.extraLarge * root.animDirection
        type: Anim.FastSpatial
    }

    Behavior on currentDate {
        SequentialAnimation {
            ParallelAnimation {
                ScriptAction {
                    script: Qt.callLater(() => trOutAnim.start())
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 0
                    type: Anim.FastEffects
                }
            }
            ScriptAction {
                script: {
                    trOutAnim.complete();
                    root.animTranslate = root.Tokens.padding.extraLarge * -root.animDirection;
                }
            }
            PropertyAction {}
            ParallelAnimation {
                Anim {
                    target: root
                    property: "animTranslate"
                    to: 0
                    type: Anim.DefaultSpatial
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            id: monthNavigationRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                isRound: true
                icon: "chevron_left"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.screenState.dashboardDate = new Date(root.nonAnimCurrYear, root.nonAnimCurrMonth - 1, 1)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.large * 2
                implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.extraSmall * 2

                StateLayer {
                    color: Colours.palette.m3primary
                    radius: pressed ? Tokens.rounding.small : height / 2
                    disabled: {
                        const now = new Date();
                        return root.nonAnimCurrMonth === now.getMonth() && root.nonAnimCurrYear === now.getFullYear();
                    }
                    onClicked: root.screenState.dashboardDate = new Date()

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                StyledText {
                    id: monthYearDisplay

                    opacity: root.animOpacity
                    transform: Translate {
                        x: root.animTranslate
                    }

                    anchors.centerIn: parent
                    text: grid.title
                    color: Colours.palette.m3primary
                    font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).build()
                }
            }

            IconButton {
                isRound: true
                icon: "chevron_right"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.screenState.dashboardDate = new Date(root.nonAnimCurrYear, root.nonAnimCurrMonth + 1, 1)
            }

            IconButton {
                isRound: true
                icon: "add"
                type: IconButton.Tonal
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: {
                    root.screenState.dashboard = false;
                    AgendaEvents.openForm(new Date());
                }
            }
        }

        DayOfWeekRow {
            id: daysRow

            Layout.fillWidth: true
            locale: grid.locale

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName.slice(0, 2) // "Wed" / "Thu" are wider than a day cell and ran into each other
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: (model.day === 0 || model.day === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight

            opacity: root.animOpacity
            transform: Translate {
                x: root.animTranslate
            }

            MonthGrid {
                id: grid

                month: root.currMonth
                year: root.currYear

                anchors.fill: parent

                spacing: 3
                locale: Qt.locale()

                delegate: Item {
                    id: dayItem

                    required property var model

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small

                    readonly property var events: root.dayEvents[Qt.formatDate(model.date, "yyyy-MM-dd")] ?? []
                    readonly property bool hasHoliday: events.some(e => e.holiday)

                    // Click a day to add an event on it
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        ToolTip.visible: containsMouse && dayItem.events.length > 0
                        ToolTip.delay: 300
                        ToolTip.text: dayItem.events.map(e => e.title).join("\n")
                        onClicked: {
                            root.screenState.dashboard = false;
                            AgendaEvents.openForm(dayItem.model.date);
                        }
                    }

                    // dot under the date: your events in the accent colour, public holidays and festivals in the tertiary one
                    Rectangle {
                        visible: dayItem.events.length > 0 && dayItem.model.month === grid.month
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 4
                        height: 4
                        radius: 2
                        color: dayItem.hasHoliday ? Colours.palette.m3tertiary : Colours.palette.m3secondary
                    }

                    StyledText {
                        id: text

                        anchors.centerIn: parent

                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        color: {
                            const dayOfWeek = dayItem.model.date.getDay();
                            if (dayOfWeek === 0 || dayOfWeek === 6)
                                return Colours.palette.m3tertiary;

                            return Colours.palette.m3onSurfaceVariant;
                        }
                        opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                        font: Tokens.font.body.small
                    }
                }
            }

            MaterialShape {
                id: todayIndicator

                readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                property Item today

                onTodayItemChanged: {
                    if (todayItem)
                        today = todayItem;
                }

                x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                y: today ? today.y - Tokens.padding.extraSmall - 1 : 0

                implicitSize: today ? Math.max(today.implicitWidth, today.implicitHeight) + Tokens.padding.extraSmall * 2 : 0
                shape: MaterialShape.Sunny

                clip: true
                color: Colours.palette.m3primary

                opacity: todayItem ? 1 : 0

                Colouriser {
                    x: -todayIndicator.x
                    y: -todayIndicator.y

                    implicitWidth: grid.width
                    implicitHeight: grid.height

                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }
            }
        }
    }
}
