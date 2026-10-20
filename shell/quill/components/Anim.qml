import QtQuick
import qs.quill

// Quill's one motion curve (Theme.curve): every number animation in Quill uses it.
NumberAnimation {
    duration: Theme.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
