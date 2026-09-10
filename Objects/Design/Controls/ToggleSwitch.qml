import QtQuick

import qs.Objects.Theme

Item {
    id: control

    property bool checked: false
    property bool enabled: true
    signal toggled(bool value)

    implicitWidth: 44
    implicitHeight: 24
    opacity: enabled ? 1.0 : 0.4

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: control.checked ? Theme.accent : Theme.alpha(Theme.textBase, 0.16)
        border.width: Theme.borderWidth
        border.color: control.checked ? Theme.accent : Theme.border

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Rectangle {
        id: thumb
        width: parent.height - 6
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: control.checked ? parent.width - width - 3 : 3
        color: control.checked ? Theme.onAccent : Theme.textDim

        Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.InOutQuad } }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            control.checked = !control.checked
            control.toggled(control.checked)
        }
    }
}
