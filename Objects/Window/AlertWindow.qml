import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems
import qs.Objects.Widgets.Internal

// The opt in full screen alert. Deliberately unmissable — anything that does
// not want this gets a notification and the small popup instead.
PanelWindow {
    id: alertWindow

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:alert"
    WlrLayershell.keyboardFocus: alertWindow.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0

    property string kind: "alarm"
    property string label: ""

    readonly property string heading: {
        if (alertWindow.kind === "timer")
            return "Timer finished"
        if (alertWindow.kind === "tracking")
            return "Still going"
        return "Alarm"
    }

    function show(kind, label) {
        alertWindow.kind = kind
        alertWindow.label = label
        alertWindow.visible = true
        keyHandler.forceActiveFocus()
    }

    function dismiss() { alertWindow.visible = false }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: alertWindow.visible
        Keys.onEscapePressed: alertWindow.dismiss()
        Keys.onReturnPressed: alertWindow.dismiss()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.92)

        MouseArea {
            anchors.fill: parent
            onClicked: alertWindow.dismiss()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: alertWindow.heading.toUpperCase()
            color: Theme.accentText
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: 800
            font.letterSpacing: 3
        }

        DotMatrix {
            Layout.alignment: Qt.AlignHCenter
            text: ClockSystem.nowText
            dotSize: 7
            dotGap: 3
            charGap: 10
            onColor: Theme.accentText
            offColor: Theme.alpha(Theme.textBase, 0.06)

            // A slow pulse, so it reads as demanding attention without
            // flashing at whoever is in the room
            SequentialAnimation on opacity {
                running: alertWindow.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.45; duration: 900 }
                NumberAnimation { from: 0.45; to: 1.0; duration: 900 }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 700
            text: alertWindow.label
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: 700
        }

        ActionButton {
            Layout.alignment: Qt.AlignHCenter
            label: "Dismiss"
            tone: "accent"
            onActivated: alertWindow.dismiss()
        }
    }
}
