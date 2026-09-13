import QtQuick

import qs.Objects.Theme

// Bars rising with the level, the tallest lit ones warming as they approach the
// top. Reads as an amount rather than as a number you have to parse.
Item {
    id: meter

    property real level: 0
    property int bars: 7
    property real barWidth: 3
    property real gap: 2
    property real minHeight: 4
    property real maxHeight: 16
    property bool muted: false

    implicitWidth: meter.bars * meter.barWidth + (meter.bars - 1) * meter.gap
    implicitHeight: meter.maxHeight

    // A Row top aligns its children, so taller bars grew downward and the
    // whole thing read upside down. Each bar is placed against the bottom.
    Repeater {
        model: meter.bars

        delegate: Rectangle {
            required property int index

            readonly property real step: (index + 1) / meter.bars
            readonly property bool lit:
                !meter.muted && meter.level >= (index / meter.bars)

            x: index * (meter.barWidth + meter.gap)
            width: meter.barWidth
            height: meter.minHeight + (meter.maxHeight - meter.minHeight) * step
            y: meter.height - height
            radius: meter.barWidth / 2

            color: {
                if (!lit)
                    return Theme.alpha(Theme.textBase, 0.12)
                if (step > 0.85)
                    return Theme.danger
                if (step > 0.6)
                    return Theme.warn
                return Theme.accent
            }

            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
    }
}
