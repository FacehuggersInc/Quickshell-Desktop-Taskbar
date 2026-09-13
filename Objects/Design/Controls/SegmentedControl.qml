import QtQuick

import qs.Objects.Theme

Item {
    id: control

    // [{ label, value, color }] — color is optional and tints the track
    property var options: []
    property var value: null
    signal picked(var value)

    readonly property int index: {
        var list = control.options ? control.options : []
        for (var i = 0; i < list.length; i++) {
            if (list[i].value === control.value)
                return i
        }
        return 0
    }

    // Segments size to the widest label rather than a fixed guess, so a long
    // option like "Compositor" is not clipped
    property real slot: Theme.controlMinWidth / 2

    function measure() {
        var widest = 0
        for (var i = 0; i < row.children.length; i++) {
            var seg = row.children[i]
            if (seg && seg.textWidth !== undefined)
                widest = Math.max(widest, seg.textWidth)
        }
        control.slot = Math.max(46, Math.ceil(widest) + 24)
    }

    implicitWidth: slot * Math.max(1, options ? options.length : 1)
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1.0 : 0.4

    onOptionsChanged: Qt.callLater(measure)
    Component.onCompleted: measure()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.textBase, 0.10)
        border.width: Theme.borderWidth
        border.color: Theme.border
    }

    Rectangle {
        id: thumb
        width: control.slot - 4
        height: parent.height - 4
        radius: height / 2
        y: 2
        x: control.index * control.slot + 2

        color: {
            var opt = control.options[control.index]
            return opt && opt.color ? opt.color : Theme.accent
        }

        Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.InOutQuad } }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Row {
        id: row
        anchors.fill: parent

        Repeater {
            model: control.options ? control.options : []

            delegate: Item {
                id: segment
                required property var modelData
                required property int index

                readonly property real textWidth: segmentText.implicitWidth

                width: control.slot
                height: control.height

                onTextWidthChanged: Qt.callLater(control.measure)

                Text {
                    id: segmentText
                    anchors.centerIn: parent
                    text: segment.modelData.label
                    color: segment.index === control.index ? Theme.onAccent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.valueSize
                    font.weight: segment.index === control.index ? 700 : 500

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }

                MouseArea {
                    anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // No assignment here. Writing value breaks whatever
                        // binding the caller gave it, so the control stops
                        // following its source — which is how a view could be
                        // reopened showing the wrong tab.
                        control.picked(segment.modelData.value)
                    }
                }
            }
        }
    }
}
