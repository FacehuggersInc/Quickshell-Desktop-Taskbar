import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: argPopup
    implicitHeight: 45
    implicitWidth: 500
    sidePadding: 0
    fadingEffectMax: 1.0
    requireFocusGrab: true

    // Set by AppBar before opening
    property var contextTarget: null
    property var contextIcon: null
    signal launched()

    function acceptAndCall(execute) {
        if (execute && contextTarget) {
            root.execute(root.combine(contextTarget.command.split(" "), inputField.text.split(" ")))
        }
        argPopup.forceClose()
        inputField.text = ""
        argPopup.launched()
    }

    content: RowLayout {
        anchors.fill: parent
        anchors.topMargin: 5
        spacing: 10

        Image {
            id: argIcon
            source: argPopup.contextIcon || ""
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            fillMode: Image.PreserveAspectFit
        }

        TextField {
            id: inputField
            Layout.fillWidth: true
            color: root.theme.text
            cursorDelegate: Rectangle {
                width: 2
                color: root.theme.primary
            }
            font.family: root.settings.fontFamily
            font.weight: 500
            font.pixelSize: 15
            background: Rectangle {
                color: root.theme.surface
                border.width: 0
                radius: 15
            }
            onAccepted: argPopup.acceptAndCall(true)
        }

        IconButton {
            iconName: "close"
            iconSize: 35
            tooltipText: "Close Args Popup"
            color: root.theme.text
            onClicked: argPopup.acceptAndCall(false)
        }
    }
}