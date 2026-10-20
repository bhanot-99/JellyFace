pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.utils
import qs.quill
import qs.quill.components

// Wi-Fi: on/off, rescan, every network in reach (the connected one first). A saved or open network connects on
// click; a secured new one asks for its password right in the list.
ListPage {
    id: root

    readonly property var networks: [...Nmcli.networks].sort((a, b) => (b.active - a.active) || (b.strength - a.strength)).filter((n, i, all) => n.ssid && all.findIndex(m => m.ssid === n.ssid) === i)
    property string asking: "" // the SSID whose password is being typed
    property string failed: ""

    count: networks.length

    function connect(n: var): void {
        if (n.active)
            return;
        failed = "";
        Nmcli.connectToNetworkWithPasswordCheck(n.ssid, n.isSecure, result => {
            if (result.needsPassword) {
                root.asking = n.ssid;
            } else if (!result.success) {
                root.failed = n.ssid;
            }
        }, n.bssid);
    }

    onActivate: i => connect(networks[i])
    Component.onCompleted: Nmcli.rescanWifi()

    header: PageHeader {
        title: "Wi-Fi"

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 30
            icon: "refresh"
            onClicked: Nmcli.rescanWifi()
            rotation: Nmcli.scanning ? 360 : 0

            Behavior on rotation {
                RotationAnimation { duration: 900; direction: RotationAnimation.Clockwise }
            }
        }

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: Nmcli.wifiEnabled
            onToggled: c => Nmcli.enableWifi(c)
        }
    }

    ListRow {
        visible: !!Nmcli.activeEthernet
        width: parent.width
        icon: "lan"
        title: "Ethernet"
        subtitle: Nmcli.activeEthernet?.connection ?? ""
        checked: true
        trailing: "Connected"
    }

    Label {
        visible: Nmcli.wifiEnabled && root.networks.length === 0
        width: parent.width
        height: 60
        horizontalAlignment: Text.AlignHCenter
        text: Nmcli.scanning ? "Looking for networks…" : "No networks found"
        secondary: true
    }

    Label {
        visible: !Nmcli.wifiEnabled
        width: parent.width
        height: 60
        horizontalAlignment: Text.AlignHCenter
        text: "Wi-Fi is off"
        secondary: true
    }

    Repeater {
        model: Nmcli.wifiEnabled ? root.networks : []

        Column {
            id: entry

            required property var modelData
            required property int index
            readonly property bool connecting: Nmcli.connecting && Nmcli.connectingSsid() === modelData.ssid

            objectName: `row${index}`
            width: parent.width

            ListRow {
                width: parent.width
                icon: Icons.getNetworkIcon(entry.modelData.strength ?? 0)
                title: entry.modelData.ssid
                current: root.current === entry.index
                checked: entry.modelData.active
                busy: entry.connecting
                trailing: entry.modelData.active ? "Connected" : entry.connecting ? "Connecting…" : root.failed === entry.modelData.ssid ? "Couldn't connect" : Nmcli.hasSavedProfile(entry.modelData.ssid) ? "Saved" : ""
                onClicked: {
                    root.current = entry.index;
                    root.connect(entry.modelData);
                }

                Icon {
                    visible: entry.modelData.isSecure && !entry.modelData.active
                    name: "lock"
                    size: 14
                    color: Theme.textMuted
                }
            }

            // the password, asked for in place
            Rectangle {
                visible: root.asking === entry.modelData.ssid
                width: parent.width
                height: visible ? 44 : 0
                radius: Theme.radiusRow
                color: Theme.well

                TextInput {
                    id: pw

                    anchors.left: parent.left
                    anchors.right: go.left
                    anchors.margins: Theme.s4
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    font.family: Theme.font
                    font.pixelSize: Theme.body
                    color: Theme.text
                    focus: parent.visible
                    onVisibleChanged: if (visible) forceActiveFocus()
                    Keys.onReturnPressed: go.submit()
                    Keys.onEnterPressed: go.submit()
                    Keys.onEscapePressed: root.asking = ""

                    Label {
                        visible: pw.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Password for ${entry.modelData.ssid}`
                        muted: true
                    }
                }

                IconButton {
                    id: go

                    function submit(): void {
                        if (!pw.text)
                            return;
                        const n = entry.modelData;
                        Nmcli.connectToNetwork(n.ssid, pw.text, n.bssid, result => {
                            if (!result.success)
                                root.failed = n.ssid;
                        });
                        pw.text = "";
                        root.asking = "";
                    }

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    icon: "arrow_forward"
                    active: pw.text !== ""
                    onClicked: submit()
                }
            }
        }
    }
}
