import QtQuick
import QtQuick.Controls.Basic

import qs.Objects.Theme

Item {
    id: control

    property string text: ""
    property string placeholder: ""
    property bool invalid: false
    readonly property alias hasFocus: field.activeFocus
    signal committed(string value)

    // Enter, as distinct from committed() which also fires on focus loss
    signal accepted(string value)

    function focusInput() { field.forceActiveFocus() }

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

        Component.onCompleted: text = control.text
        placeholderText: control.placeholder
                color: Theme.text
        placeholderTextColor: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.valueSize
        verticalAlignment: Text.AlignVCenter
        selectByMouse: true
        background: null

        // Live, so search boxes filter as you type. committed() still fires on
        // enter or focus loss for fields that write to config.
        onTextChanged: control.text = text
        onEditingFinished: control.committed(text)
        onAccepted: control.accepted(text)

        // External changes push in without fighting the live binding above
        Connections {
            target: control
            function onTextChanged() {
                if (!field.activeFocus && field.text !== control.text)
                    field.text = control.text
            }
        }
    }
}
