import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: runPopup
    implicitHeight: 45
    implicitWidth: 500
    sidePadding: 0
    fadingEffectMax: 1.0
    requireFocusGrab: true

    signal launched(string command)

    function acceptAndRun(execute) {
        var cmd = runField.text.trim()
        if (execute && cmd !== "") {
            root.execute(root.cmd("terminal_run").concat([cmd]))
            runPopup.launched(cmd)
        }
        runPopup.forceClose()
        runField.text = ""
    }

    content: RowLayout {
        anchors.fill: parent
        anchors.topMargin: 5
        spacing: 10

        Image {
            source: root.iconSource("terminal")
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            fillMode: Image.PreserveAspectFit
            opacity: 0.7
        }

        TextField {
            id: runField
            Layout.fillWidth: true
            placeholderText: "Run command..."
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
            onAccepted: runPopup.acceptAndRun(true)
        }

        IconButton {
            iconName: "close"
            iconSize: 35
            tooltipText: "Close"
            color: root.theme.text
            onClicked: runPopup.acceptAndRun(false)
        }
    }
}