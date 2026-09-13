import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// A row whose whole surface carries the current state: the fill colour, the
// icon and the caption all change together, and the three marks on the right
// say which of three it is. Clicking anywhere advances; clicking a mark picks.
Rectangle {
    id: control

    property int value: 0
    property var modes: []
    signal picked(int value)

    readonly property var current:
        (control.value >= 0 && control.value < control.modes.length)
            ? control.modes[control.value]
            : (control.modes.length > 0 ? control.modes[0] : null)

    Layout.fillWidth: true
    Layout.preferredHeight: 52

    radius: Theme.radiusSmall
    color: control.current ? Theme.alpha(control.current.tint, 0.22)
                           : Theme.alpha(Theme.scrimBase, 0.35)
    border.width: Theme.borderWidth
    border.color: control.current ? Theme.alpha(control.current.tint, 0.65)
                                  : Theme.alpha(Theme.textBase, 0.10)
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.durNormal } }
    Behavior on border.color { ColorAnimation { duration: Theme.durNormal } }

    // A wash that leans toward the side the state sits on, so the row reads
    // differently at a glance even before the icon registers
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        opacity: 0.55
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: control.value === 1 && control.current
                    ? Theme.alpha(control.current.tint, 0.30) : "transparent"
            }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop {
                position: 1.0
                color: control.value === 2 && control.current
                    ? Theme.alpha(control.current.tint, 0.30) : "transparent"
            }
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
        color: control.current ? Theme.alpha(control.current.tint, 0.35)
                               : Theme.alpha(Theme.textBase, 0.08)

        Icon {
            anchors.centerIn: parent
            iconName: control.current ? control.current.icon : "wallpaper"
            iconSize: 16
            color: control.current ? control.current.tint : Theme.textDim
        }
    }

    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: 10
        anchors.right: marks.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: control.current ? control.current.label : ""
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.labelSize
            font.weight: 600
        }

        Text {
            width: parent.width
            text: control.current ? control.current.detail : ""
            elide: Text.ElideRight
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }
    }

    Row {
        id: marks
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: control.modes

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: index === control.value ? 22 : 8
                height: 8
                radius: 4
                color: index === control.value
                    ? modelData.tint : Theme.alpha(Theme.textBase, 0.22)

                Behavior on width { NumberAnimation { duration: Theme.durFast } }
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        control.value = index
                        control.picked(index)
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var next = (control.value + 1) % Math.max(1, control.modes.length)
            control.value = next
            control.picked(next)
        }
    }
}
