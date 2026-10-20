import QtQuick
import qs.drift

ColorAnimation {
    duration: Theme.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
