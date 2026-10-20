import QtQuick
import qs.drift

// Drift's one motion curve (Theme.curve): every number animation in Drift uses it.
NumberAnimation {
    duration: Theme.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
