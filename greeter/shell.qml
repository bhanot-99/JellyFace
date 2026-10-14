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

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.25)
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(parent.height * 0.5, 460)
                height: width * 1.5
                radius: width / 8
                color: root.col("surface", "#232423")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: card.width / 10
                    spacing: card.width / 25

                    Item { Layout.fillHeight: true }

                    Text {
                        id: clock
                        Layout.alignment: Qt.AlignHCenter
                        color: root.col("primary", "#B0ADAD")
                        font.pixelSize: card.width / 5
                        font.weight: Font.Bold
                        text: Qt.formatTime(new Date(), "hh:mm")
                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: root.col("onSurfaceVariant", "#8D8B8B")
                        font.pixelSize: card.width / 20
                        text: Qt.formatDate(new Date(), "dddd, d MMMM")
                    }

                    // Round avatar drawn on a Canvas: clipping effects need a GPU, the greeter renders in software
                    Canvas {
                        id: avatar
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: card.width / 3
                        Layout.preferredHeight: card.width / 3

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
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                            ctx.fillStyle = root.col("surfaceContainerHigh", "#3D3D3D");
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

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: root.col("onSurface", "#B0ADAD")
                        font.pixelSize: card.width / 16
                        text: root.user
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: card.width / 8
                        radius: height / 2
                        color: root.col("surfaceContainer", "#303030")
                        border.width: 2
                        border.color: root.error ? root.col("error", "#CF6679") : root.col("primary", "#B0ADAD")

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Repeater {
                                model: root.buffer.length
                                Rectangle {
                                    width: 9
                                    height: 9
                                    radius: 5
                                    color: root.col("onSurface", "#B0ADAD")
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.buffer.length === 0
                            color: root.col("outline", "#767474")
                            font.pixelSize: card.width / 24
                            text: root.busy ? "Signing in…" : "Password"
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: root.col("error", "#CF6679")
                        font.pixelSize: card.width / 24
                        text: root.error
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: card.width / 12
                        Repeater {
                            model: [
                                { label: "Sleep", cmd: ["systemctl", "suspend"] },
                                { label: "Restart", cmd: ["systemctl", "reboot"] },
                                { label: "Shut down", cmd: ["systemctl", "poweroff"] }
                            ]
                            Text {
                                required property var modelData
                                color: root.col("onSurfaceVariant", "#8D8B8B")
                                font.pixelSize: card.width / 26
                                text: modelData.label
                                MouseArea {
                                    anchors.fill: parent
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
        Loader { id: testView; anchors.fill: parent; sourceComponent: screenContent }
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
