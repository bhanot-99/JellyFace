import QtQuick
import qs.quill

// A segmented control ("Saver | Balanced | Performance"): a white or accent pill slides to the chosen option.
Rectangle {
    id: root

    property list<string> options
    property list<string> labels // shown instead of options when set
    property string current
    property bool accentFill // the chosen pill in the accent colour (settings) rather than white (Control Center)
    signal picked(string option)

    readonly property int index: Math.max(0, options.indexOf(current))
    readonly property real segment: (width - 8) / Math.max(1, options.length)

    implicitWidth: 300
    implicitHeight: 36
    radius: height / 2
    color: Theme.well

    Rectangle {
        x: 4 + root.index * root.segment
        y: 4
        width: root.segment
        height: root.height - 8
        radius: height / 2
        visible: root.options.indexOf(root.current) >= 0
        color: root.accentFill ? Theme.accent : Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : "#FFFFFF"
        border.width: 1
        border.color: root.accentFill ? "transparent" : Theme.rimSoft

        Behavior on x {
            Anim {}
        }
    }

    Row {
        x: 4
        y: 4

        Repeater {
            model: root.options

            Item {
                id: seg

                required property string modelData
                required property int index

                width: root.segment
                height: root.height - 8

                Label {
                    anchors.centerIn: parent
                    text: root.labels.length > seg.index ? root.labels[seg.index] : seg.modelData
                    size: Theme.small
                    font.weight: Font.Medium
                    color: root.current === seg.modelData && root.accentFill ? "#FFFFFF" : root.current === seg.modelData ? Theme.text : Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(seg.modelData)
                }
            }
        }
    }
}
