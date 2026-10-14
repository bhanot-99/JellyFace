// JellyFace login greeter: runs under greetd (as the cosmic-greeter user) instead of cosmic-greeter.
// Standalone on purpose (QtQuick + Quickshell only): it must keep working with no user session and no JellyFace plugin.
// Data comes from $JF_GREETER_DATA (default /var/lib/jellyface-greeter): scheme.json, bg.jpg, face.png, greeter.json
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    readonly property string dataDir: Quickshell.env("JF_GREETER_DATA") || "/var/lib/jellyface-greeter"
    readonly property bool testMode: Quickshell.env("JF_GREETER_TEST") === "1"

    property string user: "bhanot"
    property string sessionCmd: "start-cosmic"
    property var c: ({})
    property string error: ""
    property bool busy: false
    property string buffer: ""
    property bool started: false
    readonly property string fontFamily: "Google Sans Flex"

    function col(name, fallback) {
        const v = c[name];
        return v ? "#" + v : fallback;
    }

    FileView {
        path: root.dataDir + "/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.c = JSON.parse(text()).colours;
            } catch (e) {}
        }
    }

    FileView {
        path: root.dataDir + "/greeter.json"
        onLoaded: {
            try {
                const j = JSON.parse(text());
                if (j.user)
                    root.user = j.user;
                if (j.session)
                    root.sessionCmd = j.session;
            } catch (e) {}
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, isError, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(root.buffer);
        }

        function onError(message) {
            root.error = "Login service error: " + message;
            root.busy = false;
            root.buffer = "";
        }

        function onAuthFailure(message) {
            root.error = "Wrong password";
            root.busy = false;
            root.buffer = "";
            Greetd.cancelSession();
        }

        function onReadyToLaunch() {
            root.started = true;
            Greetd.launch([root.sessionCmd], [], true);
        }
    }

    function submit() {
        if (busy || buffer.length === 0)
            return;
        // greetd only asks for the password once a session exists; the answer is sent from onAuthMessage.
        error = "";
        busy = true;
        Greetd.createSession(user);
    }

    Process {
        id: power
    }

    // Heartbeat: the launcher waits for this file to know the greeter really got on screen (else it falls back).
    Process {
        id: alive
        command: ["touch", (Quickshell.env("JF_GREETER_RUN") || root.dataDir + "/run") + "/alive"]
    }

    Timer {
        interval: 1500
        running: !root.testMode
        onTriggered: alive.running = true
    }

    Component {
        id: screenContent

        FocusScope {
            id: scope
            focus: true

            Keys.onPressed: event => {
                if (root.busy || root.started)
                    return;
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.submit();
                } else if (event.key === Qt.Key_Backspace) {
                    root.buffer = (event.modifiers & Qt.ControlModifier) ? "" : root.buffer.slice(0, -1);
                } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
                    root.buffer += event.text;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: root.col("background", "#232423")
            }

            Image {
                anchors.fill: parent
                source: "file://" + root.dataDir + "/bg.jpg"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Decoded tiny and scaled up smoothly = a cheap blur that also works with software rendering
                sourceSize: Qt.size(64, 36)
                smooth: true
            }

            // Same layout as the JellyFace lock screen: a 16:9 rounded panel, side cards, centred clock / avatar / password pill
            Item {
                id: lay
                anchors.fill: parent
                readonly property real cs: Math.min(1, height / 1440)
                readonly property real centerW: 600 * cs
                readonly property real pad: Math.max(8, 32 * Math.min(1, height / 1080))

                Rectangle {
                    id: panel
                    anchors.centerIn: parent
                    height: parent.height * 0.7
                    width: height * 16 / 9
                    radius: 42
                    color: root.col("surface", "#232423")
                }

                RowLayout {
                    anchors.fill: panel
                    anchors.margins: lay.pad
                    spacing: lay.pad * 2

                    // Left card: power actions
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 22
                        topLeftRadius: 42
                        color: root.col("surfaceContainer", "#303030")

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: lay.pad / 1.5
                            Repeater {
                                model: [
                                    { label: "Sleep", cmd: ["systemctl", "suspend"] },
                                    { label: "Restart", cmd: ["systemctl", "reboot"] },
                                    { label: "Shut down", cmd: ["systemctl", "poweroff"] }
                                ]
                                Rectangle {
                                    required property var modelData
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: lay.centerW * 0.42
                                    implicitHeight: lay.centerW * 0.1
                                    radius: height / 2
                                    color: pm.containsMouse ? root.col("surfaceContainerHighest", "#595959") : root.col("surfaceContainerHigh", "#3D3D3D")
                                    Text {
                                        anchors.centerIn: parent
                                        color: root.col("onSurface", "#B0ADAD")
                                        font.family: root.fontFamily
                                        font.pixelSize: lay.centerW / 28
                                        text: parent.modelData.label
                                    }
                                    MouseArea {
                                        id: pm
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (!root.testMode) {
                                                power.command = parent.modelData.cmd;
                                                power.running = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Centre column
                    ColumnLayout {
                        Layout.preferredWidth: lay.centerW
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        spacing: lay.pad

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: lay.pad / 2
                            implicitWidth: hours.implicitWidth + minutes.implicitWidth + 6
                            implicitHeight: hours.implicitHeight * 0.78
                            Text {
                                id: hours
                                y: -hours.implicitHeight * 0.12
                                color: root.col("primary", "#B0ADAD")
                                font.family: root.fontFamily
                                font.pixelSize: lay.centerW * 0.36
                                font.weight: Font.Medium
                                text: Qt.formatTime(new Date(), "hh")
                            }
                            Text {
                                id: minutes
                                anchors.right: parent.right
                                y: hours.y
                                color: root.col("secondary", "#B0ADAD")
                                font: hours.font
                                text: Qt.formatTime(new Date(), "mm")
                            }
                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    const d = new Date();
                                    hours.text = Qt.formatTime(d, "hh");
                                    minutes.text = Qt.formatTime(d, "mm");
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: root.col("onSurface", "#B0ADAD")
                            font.family: root.fontFamily
                            font.pixelSize: lay.centerW / 22
                            font.weight: Font.DemiBold
                            text: Qt.formatDate(new Date(), "dddd • d MMM").toUpperCase()
                        }

                        // Rounded-shell avatar on a Canvas: clipping effects need a GPU, the greeter renders in software
                        Canvas {
                            id: avatar
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: lay.pad
                            Layout.preferredWidth: lay.centerW * 0.42
                            Layout.preferredHeight: lay.centerW * 0.42

                            Image {
                                id: face
                                visible: false
                                source: "file://" + root.dataDir + "/face.png"
                                sourceSize.height: 256
                                onStatusChanged: if (status === Image.Ready) avatar.loadImage(source)
                            }

                            onImageLoaded: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const r = width * 0.3;
                                ctx.beginPath();
                                ctx.moveTo(r, 0);
                                ctx.arcTo(width, 0, width, height, r);
                                ctx.arcTo(width, height, 0, height, r * 0.8);
                                ctx.arcTo(0, height, 0, 0, r * 0.8);
                                ctx.arcTo(0, 0, width, 0, r);
                                ctx.closePath();
                                ctx.fillStyle = root.col("surfaceContainerHighest", "#595959");
                                ctx.fill();
                                if (isImageLoaded(face.source)) {
                                    ctx.save();
                                    ctx.clip();
                                    const s = Math.max(width / face.implicitWidth, height / face.implicitHeight);
                                    const w = face.implicitWidth * s, h = face.implicitHeight * s;
                                    ctx.drawImage(face.source, (width - w) / 2, (height - h) / 2, w, h);
                                    ctx.restore();
                                }
                            }
                        }

                        Rectangle {
                            id: pill
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: lay.pad
                            implicitWidth: lay.centerW * 0.8
                            implicitHeight: lay.centerW * 0.1
                            radius: height / 2
                            color: root.col("surfaceContainer", "#303030")
                            clip: true

                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: -pill.height / 2
                                visible: root.buffer.length === 0
                                color: root.busy ? root.col("secondary", "#B0ADAD") : root.col("outline", "#767474")
                                font.family: root.fontFamily
                                font.pixelSize: lay.centerW / 28
                                text: root.busy ? "Loading..." : "Enter your password"
                            }

                            Row {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: -pill.height / 2
                                spacing: 8
                                Repeater {
                                    model: root.buffer.length
                                    Rectangle {
                                        required property int index
                                        readonly property int kind: index % 4
                                        width: 14
                                        height: 14
                                        radius: kind === 2 ? 3 : 7
                                        rotation: kind === 1 ? 45 : 0
                                        color: root.col("onSurface", "#B0ADAD")
                                    }
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: pill.height * 0.1
                                anchors.verticalCenter: parent.verticalCenter
                                width: pill.height * 0.8
                                height: width
                                radius: width / 2
                                color: root.buffer.length ? root.col("primary", "#B0ADAD") : root.col("surfaceContainerHigh", "#3D3D3D")
                                Text {
                                    anchors.centerIn: parent
                                    color: root.buffer.length ? root.col("onPrimary", "#232423") : root.col("onSurfaceVariant", "#8D8B8B")
                                    font.pixelSize: parent.height * 0.5
                                    text: "→"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.submit()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            color: root.col("error", "#CF6679")
                            font.family: root.fontFamily
                            font.pixelSize: lay.centerW / 30
                            text: root.error ? root.error + ". Please try again." : ""
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // Right card: who is signing in
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 22
                        bottomRightRadius: 42
                        color: root.col("surfaceContainer", "#303030")

                        Column {
                            anchors.centerIn: parent
                            spacing: lay.pad / 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: root.col("onSurfaceVariant", "#8D8B8B")
                                font.family: root.fontFamily
                                font.pixelSize: lay.centerW / 30
                                text: "Signing in as"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: root.col("primary", "#B0ADAD")
                                font.family: root.fontFamily
                                font.pixelSize: lay.centerW / 16
                                font.weight: Font.Medium
                                text: root.user
                            }
                        }
                    }
                }
            }
        }
    }

    // Real greeter: a full-screen layer surface per screen. Test mode: an ordinary window, so it never covers the desktop.
    // Separate file: a PanelWindow cannot even be parsed without a layer-shell backend (the headless test has none)
    Loader {
        active: !root.testMode
        source: "Panels.qml"
        onLoaded: item.content = screenContent
    }

    FloatingWindow {
        id: testWin
        visible: root.testMode
        implicitWidth: 900
        implicitHeight: 700
        Loader { id: testView; focus: true; anchors.fill: parent; sourceComponent: screenContent }
    }

    // Test hooks (only honoured in test mode): type a password by itself, and/or save a screenshot then quit.
    Timer {
        interval: 800
        running: root.testMode && !!Quickshell.env("JF_GREETER_TEST_PW")
        onTriggered: {
            root.buffer = Quickshell.env("JF_GREETER_TEST_PW");
            root.submit();
        }
    }

    Timer {
        interval: 2500
        running: root.testMode && !!Quickshell.env("JF_GREETER_SHOT")
        onTriggered: testView.grabToImage(r => {
            r.saveToFile(Quickshell.env("JF_GREETER_SHOT"));
            Qt.quit();
        })
    }
}
