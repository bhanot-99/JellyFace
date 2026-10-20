pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.utils
import qs.drift
import qs.drift.components

// Bluetooth: on/off, look for new devices, and every known or nearby device (connected first). Click connects or
// disconnects; a new device pairs first.
ListPage {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: [...Bluetooth.devices.values].filter(d => d.name).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    count: devices.length

    function toggle(d: var): void {
        if (d.connected)
            d.disconnect();
        else if (!d.paired)
            d.pair();
        else
            d.connect();
    }

    onActivate: i => toggle(devices[i])

    header: PageHeader {
        title: "Bluetooth"

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 30
            icon: "radar"
            active: !!root.adapter?.discovering
            onClicked: if (root.adapter) root.adapter.discovering = !root.adapter.discovering
        }

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: !!root.adapter?.enabled
            onToggled: c => {
                if (root.adapter)
                    root.adapter.enabled = c;
            }
        }
    }

    Label {
        visible: !root.adapter?.enabled || root.devices.length === 0
        width: parent.width
        height: 60
        horizontalAlignment: Text.AlignHCenter
        text: !root.adapter ? "No Bluetooth adapter" : !root.adapter.enabled ? "Bluetooth is off" : root.adapter.discovering ? "Looking for devices…" : "No devices yet — press the radar to look"
        secondary: true
    }

    Repeater {
        model: root.adapter?.enabled ? root.devices : []

        ListRow {
            id: row

            required property var modelData
            required property int index
            readonly property bool working: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting || modelData.pairing

            objectName: `row${index}`
            width: parent.width
            icon: Icons.getBluetoothIcon(modelData.icon)
            title: modelData.name
            current: root.current === index
            busy: working
            trailing: modelData.connected ? `Connected${modelData.batteryAvailable ? ` · ${Math.round(modelData.battery * 100)}%` : ""}` : working ? "Connecting…" : modelData.paired ? "Not connected" : "New"
            onClicked: {
                root.current = index;
                root.toggle(modelData);
            }
        }
    }
}
