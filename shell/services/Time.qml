pragma Singleton

import QtQuick
import Quickshell
import Jellyface.Config
import Jellyface.I18n

Singleton {
    property alias enabled: clock.enabled
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    readonly property int seconds: clock.seconds

    readonly property string timeStr: format(Units.twelveHourClock ? "hh:mm:A" : "hh:mm")
    readonly property list<string> timeComponents: timeStr.split(":")
    readonly property string hourStr: timeComponents[0] ?? ""
    readonly property string minuteStr: timeComponents[1] ?? ""
    readonly property string amPmStr: timeComponents[2] ?? ""

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock

        // The clock only needs to tick every second while a seconds display is switched on; otherwise it wakes the shell once a
        // minute instead of 86,400 times a day (every binding on the time re-evaluates on each tick).
        precision: GlobalConfig.bar.clock.showSeconds || GlobalConfig.dashboard.showClockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
