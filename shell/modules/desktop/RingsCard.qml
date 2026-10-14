import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Jellyface.Config
import Jellyface.Services
import qs.components
import qs.components.controls
import qs.services

// CPU, memory, disk and battery as rings.
GlassCard {
    id: root

    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery

    implicitWidth: row.implicitWidth + Tokens.padding.extraLargeIncreased * 2
    implicitHeight: row.implicitHeight + Tokens.padding.extraLargeIncreased * 1.6

    ServiceRef {
        service: Cpu
    }
    ServiceRef {
        service: Memory
    }
    ServiceRef {
        service: Storage
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraLarge

        Ring {
            icon: "memory"
            label: "CPU"
            value: Cpu.percentage
            colour: Colours.palette.m3primary
        }
        Ring {
            icon: "memory_alt"
            label: "RAM"
            value: Memory.percentage
            colour: Colours.palette.m3tertiary
        }
        Ring {
            icon: "hard_disk"
            label: "Disk"
            value: Storage.percentage
            colour: Colours.palette.m3secondary
        }
        Ring {
            visible: root.hasBattery
            icon: UPower.onBattery ? "battery_full" : "battery_charging_full"
            label: "Battery"
            value: UPower.displayDevice.percentage
            colour: UPower.onBattery && UPower.displayDevice.percentage < 0.2 ? Colours.palette.m3error : Colours.palette.m3primary
        }
    }

    component Ring: ColumnLayout {
        id: ring

        required property string icon
        required property string label
        required property real value
        required property color colour

        spacing: Tokens.spacing.small

        CircularProgress {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 76
            strokeWidth: 7
            value: ring.value
            fgColour: ring.colour
            bgColour: Qt.alpha(Colours.palette.m3onSurface, 0.14)

            Behavior on clampedVal {
                Anim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: ring.icon
                fontStyle: Tokens.font.icon.large
                color: ring.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `${ring.label}  ${Math.round(ring.value * 100)}%`
            font: Tokens.font.label.medium
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
