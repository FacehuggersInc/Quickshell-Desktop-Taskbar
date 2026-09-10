import QtQuick
import QtQuick.Controls.Basic

import qs.Objects.Theme

Item {
    id: control

    property string text: ""
    property string placeholder: ""
    property bool enabled: true
    property bool invalid: false
    signal committed(string value)

    implicitWidth: 200
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1.0 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.textBase, 0.10)
        border.width: Theme.borderWidth
        border.color: control.invalid ? Theme.danger
            : (field.activeFocus ? Theme.accentLine : Theme.border)

        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    }

    TextField {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        text: control.text
        placeholderText: control.placeholder
        enabled: control.enabled
        color: Theme.text
        placeholderTextColor: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.valueSize
        verticalAlignment: Text.AlignVCenter
        selectByMouse: true
        background: null

        onEditingFinished: {
            control.text = text
            control.committed(text)
        }
    }
}
