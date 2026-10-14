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
    readonly property string fontFamily: gsf.status === FontLoader.Ready ? gsf.name : "Google Sans Flex"
    readonly property string iconFamily: "Material Symbols Outlined"
    readonly property string monoFamily: "CaskaydiaCove NFM"

    // Live values for the clock, the fetch card and the resource shapes
    property date now: new Date()
    readonly property string hh: String(now.getHours() % 12 || 12).padStart(2, "0")
    readonly property string mm: String(now.getMinutes()).padStart(2, "0")
    readonly property string ampm: now.getHours() < 12 ? "AM" : "PM"
    readonly property string dateText: Qt.formatDate(now, "dddd • d MMM").toUpperCase()
    property var wx: ({})
    property string wm: "COSMIC"
    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property real temp: 0
    property int uptimeSec: 0
    property int battery: -1
    property bool charging: false

    readonly property var weatherNames: ({ "0": "Clear", "1": "Clear", "2": "Partly cloudy", "3": "Overcast", "45": "Fog", "48": "Fog", "51": "Drizzle", "53": "Drizzle", "55": "Drizzle", "56": "Freezing drizzle", "57": "Freezing drizzle", "61": "Light rain", "63": "Rain", "65": "Heavy rain", "66": "Light rain", "67": "Heavy rain", "71": "Light snow", "73": "Snow", "75": "Heavy snow", "77": "Snow", "80": "Light rain", "81": "Rain", "82": "Heavy rain", "85": "Light snow showers", "86": "Heavy snow showers", "95": "Thunderstorm", "96": "Thunderstorm with hail", "99": "Thunderstorm with hail" })
    readonly property var weatherIcons: ({ "0": "clear_day", "1": "clear_day", "2": "partly_cloudy_day", "3": "cloud", "45": "foggy", "48": "foggy", "51": "rainy", "53": "rainy", "55": "rainy", "56": "rainy", "57": "rainy", "61": "rainy", "63": "rainy", "65": "rainy", "66": "rainy", "67": "rainy", "71": "cloudy_snowing", "73": "cloudy_snowing", "75": "snowing_heavy", "77": "cloudy_snowing", "80": "rainy", "81": "rainy", "82": "rainy", "85": "cloudy_snowing", "86": "snowing_heavy", "95": "thunderstorm", "96": "thunderstorm", "99": "thunderstorm" })
    readonly property string weatherText: wx.code !== undefined ? (weatherNames[wx.code] || "Unknown") : "No weather"
    readonly property string weatherIcon: wx.code !== undefined ? (weatherIcons[wx.code] || "air") : "cloud_alert"
    readonly property var fetchLines: {
        const m = Math.floor(uptimeSec / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        const plural = (n, w) => n + " " + w + (n === 1 ? "" : "s");
        const up = d > 0 ? plural(d, "day") + ", " + plural(h % 24, "hour") : h > 0 ? plural(h, "hour") + ", " + plural(m % 60, "minute") : plural(m, "minute");
        const l = ["WM  : " + wm, "USER: " + user, "UP  : " + up];
        if (battery >= 0)
            l.push("BATT: " + (charging ? "(+) " : "") + battery + "%");
        return l;
    }

    function fmtTemp(t) {
        return t === undefined ? "--°C" : Math.round(t) + "°C";
    }

    function col(name, fallback) {
        const v = c[name];
        return v ? "#" + v : fallback;
    }

    FontLoader {
        id: gsf
        source: "file://" + root.dataDir + "/gsf.ttf"
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

    FileView {
        path: root.dataDir + "/weather.json"
        onLoaded: {
            try {
                root.wx = JSON.parse(text());
            } catch (e) {}
        }
    }

    FileView {
        path: root.dataDir + "/fetch.json"
        onLoaded: {
            try {
                root.wm = JSON.parse(text()).wm || "COSMIC";
            } catch (e) {}
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // One small shell snippet reads CPU / memory / disk / temperature / uptime / battery every few seconds
    Process {
        id: stats
        command: ["sh", "-c", "a=$(head -1 /proc/stat); sleep 0.4; b=$(head -1 /proc/stat); " +
            "echo \"$a $b\" | awk '{i1=$5+$6;t1=0;for(k=2;k<=9;k++)t1+=$k;i2=$16+$17;t2=0;for(k=13;k<=20;k++)t2+=$k;printf \"%.1f \",(t2>t1)?100*(1-(i2-i1)/(t2-t1)):0}'; " +
            "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%.1f \",100*(1-a/t)}' /proc/meminfo; " +
            "df / --output=pcent | tail -1 | tr -d ' %\\n'; echo -n ' '; " +
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1 | awk '{printf \"%d \",$1/1000}'; [ -z \"$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null)\" ] && echo -n '0 '; " +
            "awk '{printf \"%d \",$1}' /proc/uptime; " +
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); if [ -n \"$b\" ]; then echo \"$(cat $b/capacity) $(cat $b/status)\"; else echo '-1 None'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/);
                if (p.length < 7)
                    return;
                root.cpu = parseFloat(p[0]) || 0;
                root.mem = parseFloat(p[1]) || 0;
                root.disk = parseFloat(p[2]) || 0;
                root.temp = parseFloat(p[3]) || 0;
                root.uptimeSec = parseInt(p[4]) || 0;
                root.battery = parseInt(p[5]);
                root.charging = p[6] === "Charging" || p[6] === "Full";
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: stats.running = true
    }

    // Rounded polygon shape (pentagon / slanted / gem / hexagon), optional wavy fill level and optional photo clipped to it
    component Blob: Canvas {
        id: blob
        property string kind: "hex"
        property color fill: "#555555"
        property color wave: "transparent"
        property real level: -1
        property string photo: ""

        onFillChanged: requestPaint()
        onWaveChanged: requestPaint()
        onLevelChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onImageLoaded: requestPaint()

        Image {
            id: photoImg
            visible: false
            source: blob.photo
            sourceSize.height: 384
            onStatusChanged: if (status === Image.Ready) blob.loadImage(source)
        }

        function points() {
            const w = width, h = height;
            if (kind === "pentagon") {
                const p = [];
                for (let i = 0; i < 5; i++) {
                    const a = (-90 + 72 * i) * Math.PI / 180;
                    p.push({ x: w * (0.5 + 0.5 * Math.cos(a)), y: h * (0.56 + 0.5 * Math.sin(a)) });
                }
                return p;
            }
            if (kind === "slanted")
                return [{ x: 0.16 * w, y: 0.0 }, { x: w, y: 0.0 }, { x: 0.84 * w, y: h }, { x: 0, y: h }].map(q => ({ x: q.x, y: q.y }));
            if (kind === "gem")
                return [{ x: 0.24 * w, y: 0.04 * h }, { x: 0.76 * w, y: 0.04 * h }, { x: w, y: 0.38 * h }, { x: 0.5 * w, y: 0.98 * h }, { x: 0, y: 0.38 * h }];
            return [{ x: 0.25 * w, y: 0.02 * h }, { x: 0.75 * w, y: 0.02 * h }, { x: w, y: 0.5 * h }, { x: 0.75 * w, y: 0.98 * h }, { x: 0.25 * w, y: 0.98 * h }, { x: 0, y: 0.5 * h }];
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const pts = points(), n = pts.length, r = Math.min(width, height) * (kind === "hex" ? 0.2 : 0.14);
            const mid = (a, b) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
            ctx.beginPath();
            const s0 = mid(pts[n - 1], pts[0]);
            ctx.moveTo(s0.x, s0.y);
            for (let i = 0; i < n; i++) {
                const m = mid(pts[i], pts[(i + 1) % n]);
                ctx.arcTo(pts[i].x, pts[i].y, m.x, m.y, r);
            }
            ctx.closePath();
            ctx.fillStyle = fill;
            ctx.fill();
            ctx.save();
            ctx.clip();
            if (level >= 0) {
                const top = height * (1 - level);
                ctx.beginPath();
                ctx.moveTo(0, height);
                ctx.lineTo(0, top);
                for (let x = 0; x <= width; x += 4)
                    ctx.lineTo(x, top + Math.sin(x / width * Math.PI * 4) * 3);
                ctx.lineTo(width, height);
                ctx.closePath();
                ctx.fillStyle = wave;
                ctx.fill();
            }
            if (photo !== "" && isImageLoaded(photoImg.source)) {
                const sc = Math.max(width / photoImg.implicitWidth, height / photoImg.implicitHeight);
                const iw = photoImg.implicitWidth * sc, ih = photoImg.implicitHeight * sc;
                ctx.drawImage(photoImg.source, (width - iw) / 2, (height - ih) / 2, iw, ih);
            }
            ctx.restore();
        }
    }

    // A single-colour silhouette of an image (alpha kept, colour replaced): MultiEffect-style tinting without a GPU
    component Tint: Canvas {
        id: tint
        property string source: ""
        property color colour: "#888888"

        onColourChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onImageLoaded: requestPaint()
        Component.onCompleted: loadImage(source)

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!isImageLoaded(source))
                return;
            ctx.drawImage(source, 0, 0, width, height);
            ctx.globalCompositeOperation = "source-in";
            ctx.fillStyle = colour;
            ctx.fillRect(0, 0, width, height);
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, isError, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(root.buffer);
        }

        function onError(message) {
            // greetd drops the session itself after a failed attempt; the follow-up cancel then errors harmlessly
            if (failGrace.running)
                return;
            root.error = "Login service error: " + message + ". Please try again.";
            root.busy = false;
            root.buffer = "";
        }

        function onAuthFailure(message) {
            // greetd has already closed the session after a failed attempt: cancelling it again only errors
            // ("Connection refused"), so just reset and let the next Enter create a fresh session.
            failGrace.restart();
            root.error = "Incorrect password. Please try again.";
            root.busy = false;
            root.buffer = "";
        }

        function onReadyToLaunch() {
            root.started = true;
            Greetd.launch([root.sessionCmd], [], true);
        }
    }

    Timer {
        id: failGrace
        interval: 1500
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

            // Same layout as the JellyFace lock screen: weather / fetch / media on the left, clock / avatar / password
            // in the centre, resources / notifications on the right. Fixed sizes of the lock screen, scaled by u.
            Item {
                id: lay
                anchors.fill: parent
                readonly property real u: Math.min(1.3, panel.height / 756)
                readonly property real cs: Math.min(1, height / 1440)
                readonly property real centerW: 600 * cs
                readonly property real pad: 24 * u
                readonly property real gap: 12 * u

                Rectangle {
                    id: panel
                    anchors.centerIn: parent
                    height: parent.height * 0.7
                    width: height * 16 / 9
                    radius: 42 * lay.u
                    color: root.col("surface", "#232423")
                }

                RowLayout {
                    anchors.fill: panel
                    anchors.margins: lay.pad
                    spacing: lay.pad * 2

                    // Left column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: lay.gap

                        // Weather
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: weatherCol.implicitHeight + 56 * lay.u
                            radius: 32 * lay.u
                            color: root.col("surfaceContainer", "#303030")

                            ColumnLayout {
                                id: weatherCol
                                anchors.top: parent.top
                                anchors.topMargin: 28 * lay.u
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2 * lay.u

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: root.col("onSurfaceVariant", "#8D8B8B")
                                    font.family: root.fontFamily
                                    font.pixelSize: 17 * lay.u
                                    text: root.weatherText
                                }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 12 * lay.u
                                    Text {
                                        color: root.col("primary", "#B0ADAD")
                                        font.family: root.fontFamily
                                        font.pixelSize: 62 * lay.u
                                        font.weight: Font.DemiBold
                                        font.variableAxes: ({ "wght": 600, "wdth": 80 })
                                        text: root.fmtTemp(root.wx.temp)
                                    }
                                    Text {
                                        color: root.col("secondary", "#B0ADAD")
                                        font.family: root.iconFamily
                                        font.pixelSize: 62 * lay.u
                                        text: root.weatherIcon
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: root.col("onSurfaceVariant", "#8D8B8B")
                                    font.family: root.fontFamily
                                    font.pixelSize: 17 * lay.u
                                    text: "Feels like " + root.fmtTemp(root.wx.feels)
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: root.col("onSurfaceVariant", "#8D8B8B")
                                    font.family: root.fontFamily
                                    font.pixelSize: 15 * lay.u
                                    text: "High " + root.fmtTemp(root.wx.hi) + " • Low " + root.fmtTemp(root.wx.lo)
                                }
                            }
                        }

                        // Fetch
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: fetchCol.implicitHeight + 56 * lay.u
                            radius: 16 * lay.u
                            color: root.col("surfaceContainer", "#303030")

                            ColumnLayout {
                                id: fetchCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 28 * lay.u
                                spacing: 10 * lay.u

                                RowLayout {
                                    spacing: 12 * lay.u
                                    Rectangle {
                                        implicitWidth: prompt.implicitWidth + 20 * lay.u
                                        implicitHeight: prompt.implicitHeight + 12 * lay.u
                                        radius: 16 * lay.u
                                        color: root.col("primary", "#B0ADAD")
                                        Text {
                                            id: prompt
                                            anchors.centerIn: parent
                                            color: root.col("onPrimary", "#232423")
                                            font.family: root.monoFamily
                                            font.pixelSize: 14 * lay.u
                                            text: ">"
                                        }
                                    }
                                    Text {
                                        color: root.col("onSurface", "#B0ADAD")
                                        font.family: root.monoFamily
                                        font.pixelSize: 14 * lay.u
                                        text: "jellyfacefetch.sh"
                                    }
                                }

                                RowLayout {
                                    spacing: 28 * lay.u
                                    Tint {
                                        Layout.preferredWidth: 96 * lay.u
                                        Layout.preferredHeight: 96 * lay.u
                                        source: "file://" + root.dataDir + "/logo.svg"
                                        colour: root.col("primary", "#B0ADAD")
                                    }
                                    ColumnLayout {
                                        spacing: 8 * lay.u
                                        Repeater {
                                            model: root.fetchLines
                                            Text {
                                                required property string modelData
                                                color: root.col("onSurface", "#B0ADAD")
                                                font.family: root.monoFamily
                                                font.pixelSize: 14 * lay.u
                                                text: modelData
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 4 * lay.u
                                    spacing: 18 * lay.u
                                    Repeater {
                                        model: 6
                                        Rectangle {
                                            required property int index
                                            implicitWidth: 28 * lay.u
                                            implicitHeight: 28 * lay.u
                                            radius: 14 * lay.u
                                            color: root.col("term" + index, "#555555")
                                        }
                                    }
                                }
                            }
                        }

                        // Media (no player runs at the login screen)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 32 * lay.u
                            color: root.col("surfaceContainer", "#303030")

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4 * lay.u
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: root.col("primary", "#B0ADAD")
                                    font.family: root.fontFamily
                                    font.pixelSize: 22 * lay.u
                                    font.weight: Font.Medium
                                    text: "Nothing playing"
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: root.col("onSurfaceVariant", "#8D8B8B")
                                    font.family: root.fontFamily
                                    font.pixelSize: 14 * lay.u
                                    text: "Try playing some music!"
                                }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 10 * lay.u
                                    spacing: 6 * lay.u
                                    Repeater {
                                        model: ["skip_previous", "play_arrow", "skip_next"]
                                        Rectangle {
                                            required property string modelData
                                            implicitWidth: (modelData === "play_arrow" ? 76 : 48) * lay.u
                                            implicitHeight: 48 * lay.u
                                            radius: height / 2
                                            color: modelData === "play_arrow" ? root.col("surfaceContainerHigh", "#3D3D3D") : root.col("surfaceContainerHighest", "#595959")
                                            opacity: 0.8
                                            Text {
                                                anchors.centerIn: parent
                                                color: root.col("onSurfaceVariant", "#8D8B8B")
                                                font.family: root.iconFamily
                                                font.pixelSize: 24 * lay.u
                                                text: parent.modelData
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
                        spacing: 24 * lay.u

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20 * lay.u
                            implicitWidth: hours.implicitWidth + minutes.implicitWidth + 6
                            implicitHeight: hourBox.digitH
                            Text {
                                id: hours
                                y: -(hourBox.lineH - hourBox.digitH) / 2
                                color: root.col("primary", "#B0ADAD")
                                font.family: root.fontFamily
                                font.pixelSize: lay.centerW * 0.36
                                font.weight: Font.Medium
                                font.variableAxes: ({ "wdth": 30, "wght": 500 })
                                text: root.hh
                            }
                            // Only measures the digits' real height (no line-spacing padding)
                            TextMetrics {
                                id: hourBox
                                font: hours.font
                                text: "00"
                                readonly property real digitH: tightBoundingRect.height
                                readonly property real lineH: boundingRect.height
                            }
                            Text {
                                id: minutes
                                anchors.right: parent.right
                                y: hours.y
                                color: root.col("secondary", "#B0ADAD")
                                font.family: root.fontFamily
                                font.pixelSize: lay.centerW * 0.195
                                font.weight: Font.Medium
                                font.variableAxes: ({ "wdth": 30, "wght": 500 })
                                text: root.mm
                            }
                            Rectangle {
                                anchors.horizontalCenter: minutes.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: minutes.implicitWidth
                                height: amPm.implicitHeight + 20 * lay.u
                                radius: 16 * lay.u
                                color: root.col("surfaceContainerHigh", "#3D3D3D")
                                Text {
                                    id: amPm
                                    anchors.centerIn: parent
                                    color: root.col("onSurface", "#B0ADAD")
                                    font.family: root.fontFamily
                                    font.pixelSize: lay.centerW * 0.075
                                    font.weight: Font.Medium
                                    text: root.ampm
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: root.col("onSurface", "#B0ADAD")
                            font.family: root.fontFamily
                            font.pixelSize: lay.centerW / 22
                            font.weight: Font.DemiBold
                            font.variableAxes: ({ "wght": 600 })
                            text: root.dateText
                        }

                        // Hexagon avatar on a Canvas: clipping effects need a GPU, the greeter renders in software
                        Blob {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 28 * lay.cs
                            Layout.bottomMargin: 16 * lay.cs
                            Layout.preferredWidth: lay.centerW * 0.7
                            Layout.preferredHeight: lay.centerW * 0.7
                            kind: "hex"
                            fill: root.col("surfaceContainerHighest", "#595959")
                            photo: "file://" + root.dataDir + "/face.png"
                        }

                        Rectangle {
                            id: pill
                            Layout.alignment: Qt.AlignHCenter
                            readonly property real full: lay.centerW * 0.8
                            implicitWidth: root.buffer.length ? full : Math.min(full, hint.implicitWidth + height * 2.2 + 12 * lay.u)
                            implicitHeight: 56 * Math.max(0.8, lay.cs)
                            radius: height / 2
                            color: root.col("surfaceContainer", "#303030")
                            clip: true

                            Behavior on implicitWidth {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: pill.height * 0.28
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.col("onSurfaceVariant", "#8D8B8B")
                                font.family: root.iconFamily
                                font.pixelSize: pill.height * 0.5
                                text: root.busy ? "progress_activity" : "lock"
                            }

                            Text {
                                id: hint
                                anchors.centerIn: parent
                                visible: root.buffer.length === 0
                                color: root.busy ? root.col("secondary", "#B0ADAD") : root.col("onSurface", "#B0ADAD")
                                opacity: 0.75
                                font.family: root.fontFamily
                                font.pixelSize: pill.height * 0.36
                                text: root.busy ? "Loading..." : "Enter your password"
                            }

                            Row {
                                anchors.centerIn: parent
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
                                    font.family: root.iconFamily
                                    font.pixelSize: parent.height * 0.55
                                    text: "arrow_forward"
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
                            text: root.error
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // Right column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: lay.gap

                        // Resources; hovering swaps them for the power buttons (the lock screen's session controls)
                        Rectangle {
                            id: resCard
                            Layout.fillWidth: true
                            implicitHeight: (width - 40 * lay.u - 2 * 20 * lay.u) / 3 + 40 * lay.u
                            radius: 32 * lay.u
                            color: root.col("surfaceContainer", "#303030")
                            clip: true

                            HoverHandler { id: resHover }

                            RowLayout {
                                id: resRow
                                anchors.fill: parent
                                anchors.margins: 20 * lay.u
                                spacing: 20 * lay.u
                                opacity: resHover.hovered ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Repeater {
                                    model: [
                                        { kind: "pentagon", icon: "memory", v: root.cpu, c: "primary", s: "primaryContainer", f: "secondary", fa: 0.3 },
                                        { kind: "slanted", icon: "memory_alt", v: root.mem, c: "tertiary", s: "onTertiary", f: "tertiary", fa: 0.3 },
                                        { kind: "gem", icon: "hard_disk", v: root.disk, c: "secondary", s: "secondaryContainer", f: "secondary", fa: 0.4 }
                                    ]
                                    Item {
                                        id: res
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Blob {
                                            anchors.fill: parent
                                            kind: res.modelData.kind
                                            fill: root.col(res.modelData.s, "#444444")
                                            wave: Qt.alpha(root.col(res.modelData.f, "#B0ADAD"), res.modelData.fa)
                                            level: res.modelData.v / 100
                                        }
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: -2
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.col("secondary", "#B0ADAD")
                                                font.family: root.iconFamily
                                                font.pixelSize: res.width * 0.2
                                                text: res.modelData.icon
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.col(res.modelData.c, "#B0ADAD")
                                                font.family: root.fontFamily
                                                font.pixelSize: res.width * 0.27
                                                font.weight: Font.Medium
                                                text: Math.round(res.modelData.v) + "%"
                                            }
                                        }
                                        // CPU temperature badge on the pentagon's corner
                                        Rectangle {
                                            visible: res.modelData.kind === "pentagon" && root.temp > 0
                                            x: res.width * 0.78
                                            y: -4 * lay.u
                                            width: res.width * 0.42
                                            height: width
                                            radius: width / 2
                                            color: root.col("secondaryContainer", "#595959")
                                            Text {
                                                anchors.centerIn: parent
                                                color: root.col("secondary", "#B0ADAD")
                                                font.family: root.fontFamily
                                                font.pixelSize: parent.width * 0.3
                                                text: Math.round(root.temp) + "°C"
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 20 * lay.u
                                spacing: 14 * lay.u
                                opacity: resHover.hovered ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Repeater {
                                    model: [
                                        { label: "Sleep", icon: "bedtime", cmd: ["systemctl", "suspend"] },
                                        { label: "Restart", icon: "restart_alt", cmd: ["systemctl", "reboot"] },
                                        { label: "Shut down", icon: "power_settings_new", cmd: ["systemctl", "poweroff"] }
                                    ]
                                    Rectangle {
                                        id: pbtn
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 20 * lay.u
                                        color: pm.containsMouse ? root.col("surfaceContainerHighest", "#595959") : root.col("surfaceContainerHigh", "#3D3D3D")
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4 * lay.u
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.col("onSurface", "#B0ADAD")
                                                font.family: root.iconFamily
                                                font.pixelSize: 34 * lay.u
                                                text: pbtn.modelData.icon
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.col("onSurfaceVariant", "#8D8B8B")
                                                font.family: root.fontFamily
                                                font.pixelSize: 12 * lay.u
                                                text: pbtn.modelData.label
                                            }
                                        }
                                        MouseArea {
                                            id: pm
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (!root.testMode) {
                                                    power.command = pbtn.modelData.cmd;
                                                    power.running = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Notifications (none exist before login)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 16 * lay.u
                            bottomRightRadius: 32 * lay.u
                            color: root.col("surfaceContainer", "#303030")

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 20 * lay.u
                                color: root.col("outline", "#767474")
                                font.family: root.monoFamily
                                font.pixelSize: 14 * lay.u
                                font.weight: Font.Medium
                                text: "Notifications"
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 18 * lay.u
                                Tint {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 200 * lay.u
                                    Layout.preferredHeight: 87 * lay.u
                                    source: "file://" + root.dataDir + "/dino.png"
                                    colour: root.col("outlineVariant", "#494747")
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: root.col("outlineVariant", "#494747")
                                    font.family: root.monoFamily
                                    font.pixelSize: 20 * lay.u
                                    font.weight: Font.Medium
                                    text: "No notifications"
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
        implicitWidth: Number(Quickshell.env("JF_GREETER_W")) || 900
        implicitHeight: Number(Quickshell.env("JF_GREETER_H")) || 700
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
