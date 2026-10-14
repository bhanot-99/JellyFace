import QtQuick
import qs.services

// The edge of a frosted-glass pane: a 1px light rim and a faint top-lit sheen fading out by the middle
Rectangle {
    border.width: 1
    border.color: Glass.rim
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Glass.sheen
        }
        GradientStop {
            position: 0.5
            color: "transparent"
        }
    }
}
