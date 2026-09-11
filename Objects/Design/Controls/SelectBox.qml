import QtQuick
import QtQuick.Controls.Basic

import qs.Objects.Theme

Item {
    id: control

    // [{ label, value }]
    property var options: []
    property var value: null
    property string placeholder: "Select"
    signal picked(var value)

    readonly property string label: {
        var list = control.options ? control.options : []
        for (var i = 0; i < list.length; i++) {
            if (list[i].value === control.value)
                return list[i].label
        }
        return placeholder
    }

    property alias open: menu.visible

    implicitWidth: Theme.controlMinWidth + 40
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1.0 : 0.4

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
                        cursorShape: Qt.PointingHandCursor
            onClicked: menu.visible ? menu.close() : menu.open()
        }
    }

    // ## Menu
    // A Popup rather than a sibling Rectangle. Raising z only reorders against
    // siblings, so an inline menu was painted over by the rows below it and read
    // as transparent. A Popup lives in the window's overlay, above everything,
    // and is never clipped by a ScrollView.

    Popup {
        id: menu

        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(list.contentHeight + 8, 220)
        padding: 4
        modal: false
        dim: false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            radius: Theme.radiusSmall
            color: Theme.menuSurface
            border.width: Theme.borderWidth
            border.color: Theme.borderStrong
        }

        contentItem: ListView {
            id: list
            clip: true
            implicitHeight: contentHeight
            model: control.options ? control.options : []
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: list.contentHeight > list.height
                    ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                required property var modelData

                width: list.width
                height: 26
                color: rowArea.containsMouse ? Theme.alpha(Theme.accent, 0.20)
                                             : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
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
                        menu.close()
                        control.picked(modelData.value)
                    }
                }
            }
        }
    }
}
