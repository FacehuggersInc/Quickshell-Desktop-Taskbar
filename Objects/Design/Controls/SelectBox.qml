import QtQuick

import qs.Objects.Theme

Item {
    id: control

    // [{ label, value }]
    property var options: []
    property var value: null
    property bool enabled: true
    property string placeholder: "Select"
    signal picked(var value)

    readonly property string label: {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === control.value)
                return options[i].label
        }
        return placeholder
    }

    property bool open: false

    implicitWidth: Theme.controlMinWidth + 40
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1.0 : 0.4
    z: open ? 50 : 0

    Rectangle {
        id: face
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: control.open ? Theme.alpha(Theme.accent, 0.16)
                            : Theme.alpha(Theme.textBase, 0.10)
        border.width: Theme.borderWidth
        border.color: control.open ? Theme.accentLine : Theme.border

        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 30
            text: control.label
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.valueSize
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: control.open ? "\u25B4" : "\u25BE"
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.valueSize
        }

        MouseArea {
            anchors.fill: parent
            enabled: control.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: control.open = !control.open
        }
    }

    Rectangle {
        id: menu
        visible: control.open
        width: parent.width
        y: parent.height + 4
        height: Math.min(list.implicitHeight + 8, 190)
        radius: Theme.radiusSmall
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.borderStrong
        clip: true

        Column {
            id: list
            width: parent.width
            y: 4

            Repeater {
                model: control.options

                delegate: Rectangle {
                    required property var modelData

                    width: menu.width
                    height: 26
                    color: rowArea.containsMouse ? Theme.alpha(Theme.accent, 0.18)
                                                 : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        elide: Text.ElideRight
                        color: modelData.value === control.value ? Theme.accentText : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                        font.weight: modelData.value === control.value ? 700 : 500
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            control.value = modelData.value
                            control.open = false
                            control.picked(modelData.value)
                        }
                    }
                }
            }
        }
    }
}
