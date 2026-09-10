import QtQuick

import qs.Objects.Theme

Item {
    id: control

    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1
    property string suffix: ""
    property bool enabled: true
    signal changed(int value)

    implicitWidth: Theme.controlMinWidth
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1.0 : 0.4

    function apply(next) {
        var clamped = Math.max(from, Math.min(to, next))
        if (clamped === control.value)
            return
        control.value = clamped
        control.changed(clamped)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.textBase, 0.10)
        border.width: Theme.borderWidth
        border.color: Theme.border
    }

    Text {
        anchors.centerIn: parent
        text: control.value + control.suffix
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.valueSize
        font.weight: 600
    }

    Repeater {
        model: [
            { side: "left", delta: -1, glyph: "\u2212" },
            { side: "right", delta: 1, glyph: "+" }
        ]

        delegate: Item {
            required property var modelData

            width: 26
            height: parent.height
            anchors.left: modelData.side === "left" ? parent.left : undefined
            anchors.right: modelData.side === "right" ? parent.right : undefined

            Text {
                anchors.centerIn: parent
                text: modelData.glyph
                color: stepArea.containsMouse ? Theme.accentText : Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: 700
            }

            MouseArea {
                id: stepArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: control.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: control.apply(control.value + modelData.delta * control.step)

                onPressAndHold: repeatTimer.start()
                onReleased: repeatTimer.stop()
                onCanceled: repeatTimer.stop()

                Timer {
                    id: repeatTimer
                    interval: 70
                    repeat: true
                    onTriggered: control.apply(control.value + modelData.delta * control.step)
                }
            }
        }
    }
}
