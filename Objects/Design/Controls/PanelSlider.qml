import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// A level control where the row itself is the track. Same chassis as every
// other panel row, so it lines up with them rather than being a thin slider
// floating between two labels.
Rectangle {
    id: control

    property string iconName: ""
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property string suffix: "%"

    signal moved(real value)

    readonly property real fraction:
        control.to > control.from
            ? Math.max(0, Math.min(1, (control.value - control.from)
                                      / (control.to - control.from)))
            : 0

    Layout.fillWidth: true
    Layout.preferredHeight: 52

    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.scrimBase, 0.35)
    border.width: Theme.borderWidth
    border.color: dragArea.containsMouse && control.enabled
        ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.10)
    opacity: control.enabled ? 1.0 : 0.4
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * control.fraction
        radius: parent.radius
        color: Theme.alpha(Theme.accent, 0.28)

        Behavior on width {
            enabled: !dragArea.pressed
            NumberAnimation { duration: Theme.durFast }
        }
    }

    Rectangle {
        id: iconBox
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.textBase, 0.08)

        Icon {
            anchors.centerIn: parent
            iconName: control.iconName
            iconSize: 16
            color: Theme.accentIcon
        }
    }

    Text {
        anchors.left: iconBox.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: control.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.labelSize
        font.weight: 600
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(control.value) + control.suffix
        color: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.valueSize
        font.weight: 700
    }

    // The whole row is the track
    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: control.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function apply(x) {
            var ratio = Math.max(0, Math.min(1, x / control.width))
            var next = control.from + ratio * (control.to - control.from)
            control.value = next
            control.moved(next)
        }

        onPressed: (mouse) => apply(mouse.x)
        onPositionChanged: (mouse) => {
            if (dragArea.pressed) apply(mouse.x)
        }
    }
}
