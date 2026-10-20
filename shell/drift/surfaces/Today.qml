pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.drift
import qs.drift.components

// Today (rest on the top edge, like Classic's dashboard, or click the clock): the date, a month calendar with a dot under every day that has something on it
// (your calendars and holidays, from scripts/agenda.py), what is on the chosen day, what's up next, the weather and
// what is playing. Scroll or the arrows change the month; ←/→ move the chosen day.
Surface {
    id: root

    name: "today"
    anchors.fill: parent

    property date month: new Date()
    property date chosen: new Date()
    property var dayEvents: ({})
    property var upcoming: []
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/jellyface`
    readonly property var player: Players.active

    function key(d: date): string {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function shiftMonth(n: int): void {
        month = new Date(month.getFullYear(), month.getMonth() + n, 1);
    }

    onActiveChanged: if (active) {
        month = new Date();
        chosen = new Date();
    }

    Keys.onLeftPressed: chosen = new Date(chosen.getFullYear(), chosen.getMonth(), chosen.getDate() - 1)
    Keys.onRightPressed: chosen = new Date(chosen.getFullYear(), chosen.getMonth(), chosen.getDate() + 1)
    Keys.onUpPressed: chosen = new Date(chosen.getFullYear(), chosen.getMonth(), chosen.getDate() - 7)
    Keys.onDownPressed: chosen = new Date(chosen.getFullYear(), chosen.getMonth(), chosen.getDate() + 7)
    onChosenChanged: if (chosen.getMonth() !== month.getMonth() || chosen.getFullYear() !== month.getFullYear()) month = new Date(chosen.getFullYear(), chosen.getMonth(), 1)

    blur: Region {
        BlurRegion {
            pane: sheet.body
        }
    }

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

    FileView {
        path: `${root.stateDir}/agenda.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const now = new Date();
                root.upcoming = (JSON.parse(text()).events ?? []).filter(e => new Date(e.end) > now).slice(0, 3);
            } catch (e) {
                root.upcoming = [];
            }
        }
    }

    Glass {
        id: sheet

        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: 740
        height: Math.max(left.implicitHeight, right.implicitHeight) + 40
        color: Theme.sheet
        scale: 0.96 + 0.04 * root.progress
        transformOrigin: Item.Top

        MouseArea {
            anchors.fill: parent
        }

        // ── left: the date and the month ──
        Column {
            id: left

            x: 22
            y: 18
            width: 330
            spacing: Theme.s3

            Column {
                spacing: 0

                Kicker {
                    text: Qt.formatDate(Time.date, "dddd")
                }

                Label {
                    text: Time.format("hh:mm")
                    size: 56
                    font.weight: Font.Light
                    font.letterSpacing: -2
                }

                Label {
                    text: Qt.formatDate(Time.date, "MMMM d, yyyy")
                    size: Theme.heading
                    secondary: true
                }
            }

            Tile {
                width: parent.width
                height: cal.implicitHeight + 24
                interactive: false

                WheelHandler {
                    onWheel: e => root.shiftMonth(e.angleDelta.y > 0 ? -1 : 1)
                }

                Column {
                    id: cal

                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 28

                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDate(root.month, "MMMM yyyy")
                            font.weight: Font.DemiBold
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            IconButton { size: 26; icon: "chevron_left"; onClicked: root.shiftMonth(-1) }
                            IconButton { size: 26; icon: "today"; onClicked: { root.month = new Date(); root.chosen = new Date(); } }
                            IconButton { size: 26; icon: "chevron_right"; onClicked: root.shiftMonth(1) }
                        }
                    }

                    Grid {
                        id: days

                        readonly property date first: new Date(root.month.getFullYear(), root.month.getMonth(), 1)
                        // weeks start on Monday
                        readonly property int lead: (first.getDay() + 6) % 7
                        readonly property real cell: width / 7

                        width: parent.width
                        columns: 7

                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]

                            Label {
                                required property string modelData

                                width: days.cell
                                height: 22
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                size: Theme.caption + 1
                                muted: true
                            }
                        }

                        Repeater {
                            model: 42

                            Item {
                                id: day

                                required property int index
                                readonly property date d: new Date(days.first.getFullYear(), days.first.getMonth(), index - days.lead + 1)
                                readonly property bool inMonth: d.getMonth() === root.month.getMonth()
                                readonly property bool today: root.key(d) === root.key(new Date())
                                readonly property bool picked: root.key(d) === root.key(root.chosen)
                                readonly property var events: root.dayEvents[root.key(d)] ?? []

                                width: days.cell
                                height: 34

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: day.today ? Theme.accent : day.picked ? Theme.accentSoft : dayArea.containsMouse ? Theme.tileHover : "transparent"
                                    border.width: day.picked && !day.today ? 1 : 0
                                    border.color: Theme.accent
                                }

                                Label {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: day.d.getDate()
                                    size: Theme.small
                                    font.weight: day.today ? Font.DemiBold : Font.Normal
                                    color: day.today ? "#FFFFFF" : day.inMonth ? Theme.text : Theme.textMuted
                                    opacity: day.inMonth ? 1 : 0.5
                                }

                                Rectangle {
                                    visible: day.events.length > 0
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: day.today ? "#FFFFFF" : day.events.some(e => e.holiday) ? Theme.warn : Theme.accent
                                }

                                MouseArea {
                                    id: dayArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.chosen = day.d
                                }
                            }
                        }
                    }
                }
            }

            // what's on the chosen day
            Column {
                width: parent.width
                spacing: 4

                Kicker {
                    text: root.key(root.chosen) === root.key(new Date()) ? "On today" : `On ${Qt.formatDate(root.chosen, "ddd, MMM d")}`
                }

                Label {
                    visible: (root.dayEvents[root.key(root.chosen)] ?? []).length === 0
                    text: "Nothing planned"
                    secondary: true
                    size: Theme.small
                }

                Repeater {
                    model: (root.dayEvents[root.key(root.chosen)] ?? []).slice(0, 4)

                    Row {
                        required property var modelData

                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: parent.modelData.holiday ? Theme.warn : Theme.accent
                        }

                        Label {
                            text: parent.modelData.title
                            size: Theme.small
                            width: Math.min(implicitWidth, 300)
                        }
                    }
                }
            }
        }

        // ── right: weather, up next, media ──
        Column {
            id: right

            x: left.x + left.width + 20
            y: 18
            width: sheet.width - x - 20
            spacing: Theme.s3

            Tile {
                width: parent.width
                height: 168
                interactive: false

                Row {
                    x: 16
                    y: 14
                    spacing: 14

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.icon
                        size: 44
                        color: Theme.accent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            text: Weather.temp
                            size: 34
                            font.weight: Font.Light
                        }

                        Label {
                            text: `${Weather.description} · feels ${Weather.feelsLike}`
                            size: Theme.small
                            secondary: true
                        }
                    }
                }

                Label {
                    x: parent.width - width - 16
                    y: 18
                    text: Weather.city
                    size: Theme.small
                    muted: true
                    width: Math.min(implicitWidth, 120)
                }

                Row {
                    x: 12
                    y: 92
                    width: parent.width - 24
                    spacing: 0

                    Repeater {
                        model: Weather.hourlyForecast.slice(0, 6)

                        Column {
                            required property var modelData

                            width: (parent.width) / 6
                            spacing: 2

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${parent.modelData.hour}:00`
                                size: Theme.caption + 1
                                muted: true
                            }

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: parent.modelData.icon
                                size: 20
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${parent.modelData.tempC}°`
                                size: Theme.small
                            }
                        }
                    }
                }
            }

            Tile {
                width: parent.width
                height: 44 + Math.max(1, root.upcoming.length) * 38
                interactive: false

                Kicker {
                    x: 16
                    y: 14
                    text: "Up next"
                }

                Column {
                    x: 10
                    y: 36
                    width: parent.width - 20

                    Label {
                        visible: root.upcoming.length === 0
                        x: 6
                        height: 34
                        text: "No upcoming events"
                        size: Theme.small
                        secondary: true
                    }

                    Repeater {
                        model: root.upcoming

                        Item {
                            id: ev

                            required property var modelData
                            readonly property date start: new Date(modelData.start)

                            width: parent.width
                            height: 38

                            Rectangle {
                                x: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 26
                                radius: 1.5
                                color: Theme.accent
                            }

                            Column {
                                x: 18
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24

                                Label {
                                    width: parent.width
                                    text: ev.modelData.title
                                    size: Theme.small
                                    font.weight: Font.Medium
                                }

                                Label {
                                    width: parent.width
                                    text: ev.modelData.allDay ? `${Qt.formatDate(ev.start, "ddd, MMM d")} · all day` : `${Qt.formatDate(ev.start, "ddd")} ${Qt.formatTime(ev.start, "hh:mm")}${ev.modelData.location ? " · " + ev.modelData.location : ""}`
                                    size: Theme.caption + 1
                                    muted: true
                                }
                            }
                        }
                    }
                }
            }

            Tile {
                visible: !!root.player
                width: parent.width
                height: 88
                interactive: false

                Rectangle {
                    id: art

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    height: 64
                    radius: 14
                    color: Theme.lilac
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? Players.getArtUrl(root.player) : ""
                        sourceSize: Qt.size(128, 128)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Column {
                        width: parent.width

                        Label {
                            width: parent.width
                            text: root.player?.trackTitle || "Nothing playing"
                            font.weight: Font.Medium
                        }

                        Label {
                            width: parent.width
                            text: root.player?.trackArtist || Players.getIdentity(root.player)
                            size: Theme.small
                            secondary: true
                        }
                    }

                    Row {
                        spacing: 6

                        IconButton { size: 30; icon: "skip_previous"; onClicked: root.player?.previous() }
                        IconButton { size: 30; icon: root.player?.isPlaying ? "pause" : "play_arrow"; active: true; onClicked: root.player?.togglePlaying() }
                        IconButton { size: 30; icon: "skip_next"; onClicked: root.player?.next() }
                    }
                }
            }
        }
    }
}
