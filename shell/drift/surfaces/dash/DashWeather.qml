pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.drift
import qs.drift.components

// Dashboard tab 4 — Weather: now (temperature, conditions, feels like, humidity, wind, sunrise and sunset), the next
// twelve hours, and the week with each day's low-to-high range.
Item {
    id: root

    readonly property var week: Weather.forecast
    readonly property real weekMin: Math.min(...week.map(d => d.minTempC), 99)
    readonly property real weekMax: Math.max(...week.map(d => d.maxTempC), -99)

    implicitWidth: 820
    implicitHeight: 360

    function move(dx: int, dy: int): void {
    }

    // ── now ──
    Tile {
        id: now

        width: 300
        height: parent.height
        interactive: false

        Column {
            x: 22
            y: 20
            width: parent.width - 44
            spacing: 6

            Kicker {
                text: Weather.city || "Weather"
            }

            Row {
                spacing: 14

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon
                    size: 58
                    color: Theme.accent
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.temp
                    size: 52
                    font.weight: Font.Light
                    font.letterSpacing: -1.5
                }
            }

            Label {
                text: Weather.description
                size: Theme.heading
                font.weight: Font.Medium
            }

            Label {
                text: `Feels like ${Weather.feelsLike}`
                secondary: true
            }

            Item {
                width: 1
                height: 10
            }

            Grid {
                columns: 2
                columnSpacing: 22
                rowSpacing: 12

                Repeater {
                    model: [["water_drop", "Humidity", `${Weather.humidity}%`], ["air", "Wind", `${Math.round(Weather.windSpeed)} km/h`], ["wb_twilight", "Sunrise", Weather.sunrise], ["routine", "Sunset", Weather.sunset]]

                    Row {
                        id: fact

                        required property var modelData

                        spacing: 8

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: fact.modelData[0]
                            size: 18
                            color: Theme.textSecondary
                        }

                        Column {
                            Label {
                                text: fact.modelData[1]
                                size: Theme.caption + 1
                                muted: true
                            }

                            Label {
                                text: fact.modelData[2]
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        x: now.width + 16
        width: parent.width - x
        spacing: 14

        // ── the next hours ──
        Tile {
            width: parent.width
            height: 118
            interactive: false

            Kicker {
                x: 16
                y: 12
                text: "Next hours"
            }

            Row {
                x: 8
                y: 34
                width: parent.width - 16

                Repeater {
                    model: Weather.hourlyForecast.slice(0, 12)

                    Column {
                        id: hour

                        required property var modelData

                        width: parent.width / 12
                        spacing: 4

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${hour.modelData.hour}`
                            size: Theme.caption + 1
                            muted: true
                        }

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: hour.modelData.icon
                            size: 20
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${hour.modelData.tempC}°`
                            size: Theme.small
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: hour.modelData.precipChance > 0
                            text: `${hour.modelData.precipChance}%`
                            size: Theme.caption
                            color: Theme.accent
                        }
                    }
                }
            }
        }

        // ── the week ──
        Tile {
            width: parent.width
            height: 228
            interactive: false

            Kicker {
                x: 16
                y: 12
                text: "This week"
            }

            Column {
                x: 16
                y: 34
                width: parent.width - 32

                Repeater {
                    model: root.week.slice(0, 7)

                    Item {
                        id: day

                        required property var modelData
                        required property int index
                        readonly property date d: new Date(modelData.date)
                        readonly property real span: Math.max(1, root.weekMax - root.weekMin)

                        width: parent.width
                        height: 27

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                            text: day.index === 0 ? "Today" : Qt.formatDate(day.d, "ddd")
                            font.weight: day.index === 0 ? Font.DemiBold : Font.Normal
                        }

                        Icon {
                            x: 64
                            anchors.verticalCenter: parent.verticalCenter
                            name: day.modelData.icon
                            size: 18
                        }

                        Label {
                            x: 100
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            horizontalAlignment: Text.AlignRight
                            text: `${Math.round(day.modelData.minTempC)}°`
                            secondary: true
                        }

                        // this day's range on the week's scale
                        Rectangle {
                            x: 150
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 150 - 50
                            height: 6
                            radius: 3
                            color: Theme.well

                            Rectangle {
                                x: parent.width * (day.modelData.minTempC - root.weekMin) / day.span
                                width: Math.max(6, parent.width * (day.modelData.maxTempC - day.modelData.minTempC) / day.span)
                                height: parent.height
                                radius: 3
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Theme.ice }
                                    GradientStop { position: 1; color: Theme.peach }
                                }
                            }
                        }

                        Label {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            text: `${Math.round(day.modelData.maxTempC)}°`
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
