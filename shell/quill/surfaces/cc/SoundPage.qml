pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.quill
import qs.quill.components

// Sound: where it plays (output devices) and listens (inputs), each with its volume, and every app making sound.
ListPage {
    id: root

    readonly property var outputs: Audio.sinks
    readonly property var inputs: Audio.sources

    count: outputs.length + inputs.length
    maxListHeight: 420
    onActivate: i => i < outputs.length ? Audio.setAudioSink(outputs[i]) : Audio.setAudioSource(inputs[i - outputs.length])

    header: PageHeader {
        title: "Sound"
    }

    Kicker {
        text: "Output"
        topPadding: Theme.s1
        bottomPadding: Theme.s1
        leftPadding: Theme.s2
    }

    Slider {
        x: Theme.s2
        width: parent.width - Theme.s4
        icon: Audio.muted ? "no_sound" : "volume_up"
        value: Audio.volume
        onMoved: v => Audio.setVolume(v)
    }

    Repeater {
        model: root.outputs

        ListRow {
            required property var modelData
            required property int index

            objectName: `row${index}`
            width: parent.width
            rowHeight: 36
            icon: (modelData.description ?? "").toLowerCase().includes("head") ? "headphones" : "speaker"
            title: modelData.description || modelData.nickname || modelData.name
            current: root.current === index
            checked: Audio.sink?.id === modelData.id
            onClicked: {
                root.current = index;
                Audio.setAudioSink(modelData);
            }
        }
    }

    Kicker {
        text: "Input"
        topPadding: Theme.s3
        bottomPadding: Theme.s1
        leftPadding: Theme.s2
    }

    Slider {
        x: Theme.s2
        width: parent.width - Theme.s4
        icon: Audio.sourceMuted ? "mic_off" : "mic"
        value: Audio.sourceVolume
        onMoved: v => Audio.setSourceVolume(v)
    }

    Repeater {
        model: root.inputs

        ListRow {
            required property var modelData
            required property int index

            objectName: `row${index + root.outputs.length}`
            width: parent.width
            rowHeight: 36
            icon: "mic"
            title: modelData.description || modelData.nickname || modelData.name
            current: root.current === index + root.outputs.length
            checked: Audio.source?.id === modelData.id
            onClicked: {
                root.current = index + root.outputs.length;
                Audio.setAudioSource(modelData);
            }
        }
    }

    Kicker {
        visible: Audio.streams.length > 0
        text: "Apps"
        topPadding: Theme.s3
        bottomPadding: Theme.s1
        leftPadding: Theme.s2
    }

    Repeater {
        model: Audio.streams

        Item {
            id: app

            required property var modelData

            width: parent.width
            height: 44

            Label {
                x: Theme.s2
                width: 130
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.getStreamName(app.modelData)
                size: Theme.small
            }

            Slider {
                anchors.left: parent.left
                anchors.leftMargin: 140
                anchors.right: parent.right
                anchors.rightMargin: Theme.s2
                anchors.verticalCenter: parent.verticalCenter
                value: Audio.getStreamVolume(app.modelData)
                onMoved: v => Audio.setStreamVolume(app.modelData, v)
            }
        }
    }
}
