import QtQuick

import qs.Objects.Theme

// Text that scrolls only when it does not fit, pausing at each end. Eliding a
// track title tends to cut exactly the part that identifies it.
Item {
    id: marquee

    property string text: ""
    property color color: Theme.text
    property int pixelSize: Theme.descSize
    property int weight: 600
    property int gap: 26
    property int speed: 22

    readonly property bool overflowing: label.implicitWidth > marquee.width

    clip: true
    implicitHeight: label.implicitHeight

    Text {
        id: label
        text: marquee.text
        color: marquee.color
        font.family: Theme.fontFamily
        font.pixelSize: marquee.pixelSize
        font.weight: marquee.weight
        x: marquee.overflowing ? marquee.offset : 0
        width: marquee.overflowing ? implicitWidth : marquee.width
        elide: marquee.overflowing ? Text.ElideNone : Text.ElideRight
    }

    // The second copy makes the wrap continuous rather than a jump back
    Text {
        visible: marquee.overflowing
        text: marquee.text
        color: marquee.color
        font.family: label.font.family
        font.pixelSize: label.font.pixelSize
        font.weight: label.font.weight
        x: marquee.offset + label.implicitWidth + marquee.gap
    }

    property real offset: 0

    readonly property real span: label.implicitWidth + marquee.gap

    SequentialAnimation {
        running: marquee.overflowing && marquee.visible
        loops: Animation.Infinite

        PauseAnimation { duration: 1600 }

        NumberAnimation {
            target: marquee
            property: "offset"
            from: 0
            to: -marquee.span
            duration: Math.max(1200, marquee.span * 1000 / marquee.speed)
        }

        ScriptAction { script: marquee.offset = 0 }
    }

    onTextChanged: marquee.offset = 0
}
