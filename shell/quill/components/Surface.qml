import QtQuick
import Quickshell
import qs.quill

// One of Quill's pop-up surfaces on the Stage (Control Center, command bar...). It fades and rises in when
// QuillState.open is its name, takes the keyboard, and closes on Esc. `blur` is the Region behind its glass panes
// (BlurRegion items), so the Stage blurs exactly what is shown.
FocusScope {
    id: root

    required property string name
    readonly property bool active: QuillState.open === name
    property Region blur
    // how far it rises when it appears (0 = only fades and scales)
    property real rise: 10
    // fully shown (1) or gone (0): surfaces animate their own parts from this
    property real progress: active ? 1 : 0
    // The compositor's blur can't fade, only switch on or off, so it is kept only while the surface is mostly shown;
    // held to the end of the fade-out it lingers as a blurred footprint of a pane that has already faded away.
    readonly property bool frosted: progress > 0.5

    visible: progress > 0.001
    opacity: progress
    enabled: active
    focus: active

    Behavior on progress {
        Anim {
            duration: root.active ? Theme.slow : Theme.normal
            easing.bezierCurve: root.active ? Theme.curve : Theme.curveIn
        }
    }

    transform: Translate {
        y: (1 - root.progress) * -root.rise
    }

    onActiveChanged: if (active) forceActiveFocus()
    Keys.onEscapePressed: QuillState.close()
}
