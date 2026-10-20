pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import Jellyface.Config
import Jellyface.I18n
import Jellyface.Services
import qs.services
import qs.quill
import qs.quill.components

// Dashboard tab 3 — Performance: CPU, GPU and memory as gauges (with temperatures), storage, network speed with its
// recent history, and the battery. Everything is measured only while this tab is on screen.
Item {
    id: root

    readonly property bool hasGpu: Gpu.type !== GpuType.None

    implicitWidth: 820
    implicitHeight: top.height + 14 + bottom.height

    function move(dx: int, dy: int): void {
    }

    ServiceRef {
        service: root.visible ? Cpu : null
    }

    ServiceRef {
        service: root.visible ? Gpu : null
    }

    ServiceRef {
        service: root.visible ? Memory : null
    }

    ServiceRef {
        service: root.visible ? Storage : null
    }

    ServiceRef {
        service: root.visible ? NetworkUsage : null
    }

    component Gauge: Tile {
        id: g

        property string icon
        property string label
        property string sub
        property real value
        property real temperature
        property color tint: Theme.accent

        height: 210
        interactive: false

        Ring {
            id: ring

            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            width: 124
            height: 124
            value: g.value
            color: g.value > 0.85 ? Theme.bad : g.tint

            Column {
                anchors.centerIn: parent

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: g.icon
                    size: 20
                    color: Theme.textSecondary
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Math.round(g.value * 100)}%`
                    size: Theme.title
                    font.weight: Font.DemiBold
                }

                Label {
                    visible: g.temperature > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Math.round(g.temperature)}°C`
                    size: Theme.caption + 1
                    color: g.temperature > 85 ? Theme.bad : Theme.textMuted
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: ring.bottom
            anchors.topMargin: 8
            width: parent.width - 24

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: g.label
                font.weight: Font.DemiBold
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: g.sub
                size: Theme.caption + 1
                muted: true
            }
        }
    }

    Row {
        id: top

        width: parent.width
        spacing: 14

        Gauge {
            width: (top.width - top.spacing * (root.hasGpu ? 2 : 1)) / (root.hasGpu ? 3 : 2)
            icon: "memory"
            label: "CPU"
            sub: Cpu.name
            value: Cpu.percentage
            temperature: Cpu.temperature
        }

        Gauge {
            visible: root.hasGpu
            width: (top.width - top.spacing * 2) / 3
            icon: "desktop_windows"
            label: "GPU"
            sub: Gpu.name || (Gpu.detecting ? "Detecting…" : "")
            value: Gpu.percentage
            temperature: Gpu.temperature
            tint: Qt.darker(Theme.lilac, 1.5)
        }

        Gauge {
            width: (top.width - top.spacing * (root.hasGpu ? 2 : 1)) / (root.hasGpu ? 3 : 2)
            icon: "memory_alt"
            label: "Memory"
            sub: Units.formatKibUsage(Memory.used, Memory.total)
            value: Memory.percentage
            tint: Theme.good
        }
    }

    Row {
        id: bottom

        anchors.top: top.bottom
        anchors.topMargin: 14
        width: parent.width
        spacing: 14

        // storage
        Tile {
            width: (bottom.width - bottom.spacing * 2) / 3
            height: 130
            interactive: false

            Column {
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 8

                Row {
                    spacing: 8

                    Icon { name: "hard_drive"; size: 18; color: Theme.accent }
                    Label { text: "Storage"; font.weight: Font.DemiBold }
                }

                Label {
                    text: `${Math.round((Storage.primaryDisk?.perc ?? 0) * 100)}%`
                    size: Theme.title
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.well

                    Rectangle {
                        width: parent.width * (Storage.primaryDisk?.perc ?? 0)
                        height: parent.height
                        radius: 3
                        color: (Storage.primaryDisk?.perc ?? 0) > 0.9 ? Theme.bad : Theme.accent
                    }
                }

                Label {
                    text: Storage.primaryDisk ? Units.formatKibUsage(Storage.primaryDisk.used, Storage.primaryDisk.total) : "No disks found"
                    size: Theme.caption + 1
                    muted: true
                }
            }
        }

        // network
        Tile {
            width: (bottom.width - bottom.spacing * 2) / 3
            height: 130
            interactive: false

            Row {
                x: 16
                y: 16
                spacing: 8

                Icon { name: "swap_vert"; size: 18; color: Theme.accent }
                Label { text: "Network"; font.weight: Font.DemiBold }
            }

            Column {
                x: 16
                y: 44
                spacing: 2

                Label {
                    text: `↓ ${Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true)}`
                    font.weight: Font.Medium
                }

                Label {
                    text: `↑ ${Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true)}`
                    size: Theme.small
                    secondary: true
                }
            }

            // the last minute of download speed
            Canvas {
                id: spark

                x: parent.width * 0.48
                y: 40
                width: parent.width * 0.48
                height: 70
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const b = NetworkUsage.downloadBuffer;
                    const n = b?.count ?? 0;
                    if (n < 2)
                        return;
                    const max = Math.max(b.maximum, 1024);
                    c.strokeStyle = Theme.accent;
                    c.lineWidth = 2;
                    c.lineJoin = "round";
                    c.beginPath();
                    for (let i = 0; i < n; i++) {
                        const x = i / (n - 1) * width, y = height - (b.at(i) / max) * (height - 4) - 2;
                        i ? c.lineTo(x, y) : c.moveTo(x, y);
                    }
                    c.stroke();
                }

                Connections {
                    function onValuesChanged(): void {
                        spark.requestPaint();
                    }

                    target: NetworkUsage.downloadBuffer
                    ignoreUnknownSignals: true
                }

                Connections {
                    function onAccentChanged(): void {
                        spark.requestPaint();
                    }

                    target: Theme
                }
            }
        }

        // battery
        Tile {
            width: (bottom.width - bottom.spacing * 2) / 3
            height: 130
            interactive: false

            Column {
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 8

                Row {
                    spacing: 8

                    Icon { name: Power.charging || Power.full ? "battery_charging_full" : "battery_full"; size: 18; color: Theme.good }
                    Label { text: Power.present ? "Battery" : "Power"; font.weight: Font.DemiBold }
                }

                Label {
                    text: Power.present ? `${Math.round(Power.percent * 100)}%` : (Power.profile ? Power.profile[0].toUpperCase() + Power.profile.slice(1) : "")
                    size: Theme.title
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: Power.present
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.well

                    Rectangle {
                        width: parent.width * Power.percent
                        height: parent.height
                        radius: 3
                        color: Power.percent <= 0.2 && !Power.charging ? Theme.bad : Theme.good
                    }
                }

                Label {
                    text: Power.present ? Power.timeText : "No battery"
                    size: Theme.caption + 1
                    muted: true
                }
            }
        }
    }
}
