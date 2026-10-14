import QtQuick
import QtQuick.Layouts
import Jellyface.Config
import Jellyface.I18n
import qs.components
import qs.services

// Big clock, the date and the weather.
GlassCard {
    id: root

    implicitWidth: row.implicitWidth + Tokens.padding.extraLargeIncreased * 2
    implicitHeight: row.implicitHeight + Tokens.padding.extraLargeIncreased * 2

    Component.onCompleted: Weather.reload()

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraLarge

        // time and date
        ColumnLayout {
            spacing: 0

            RowLayout {
                spacing: Tokens.spacing.small

                StyledText {
                    text: Time.timeComponents.slice(0, 2).join(":")
                    font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * 3.4).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Tokens.padding.large
                    visible: Units.twelveHourClock
                    text: Time.amPmStr
                    font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize).build()
                    color: Colours.palette.m3primary
                }
            }

            StyledText {
                text: Time.format("dddd, d MMMM")
                font: Tokens.font.title.medium
                color: Colours.palette.m3primary
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 2
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            radius: 1
            color: Qt.alpha(Colours.palette.m3onSurface, 0.2)
        }

        // weather
        RowLayout {
            spacing: Tokens.spacing.large

            MaterialIcon {
                animate: true
                text: Weather.icon
                color: Colours.palette.m3secondary
                fontStyle: Tokens.font.icon.size(Math.round(Tokens.font.headline.medium.pointSize * 2.2)).build()
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    animate: true
                    text: Weather.temp
                    font: Tokens.font.headline.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    animate: true
                    text: Weather.description
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    text: Weather.city
                    visible: text !== ""
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3outline
                }
            }
        }
    }
}
