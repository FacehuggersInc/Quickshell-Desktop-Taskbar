import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

// The quiet form, shown above the clock. What fires without opting into the
// full screen still says what it was.
PopupPanel {
    id: alertPopup

    implicitWidth: 300
    implicitHeight: body.implicitHeight + tbPadding * 2
    sidePadding: 12
    tbPadding: 12
    fadingEffectMax: 1.0
    scrollingEffect: false
    requireFocusGrab: false

    property string kind: "alarm"
    property string label: ""

    readonly property string heading: {
        if (alertPopup.kind === "timer")
            return "Timer finished"
        if (alertPopup.kind === "tracking")
            return "Still going"
        return "Alarm"
    }

    function show(kind, label, anchorItem) {
        alertPopup.kind = kind
        alertPopup.label = label
        alertPopup.forceOpen(anchorItem)
        dwell.restart()
    }

    Timer {
        id: dwell
        interval: 8000
        onTriggered: alertPopup.forceClose()
    }

    content: RowLayout {
        id: body
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.accent, 0.22)

            Icon {
                anchors.centerIn: parent
                iconName: alertPopup.kind === "timer" ? "history" : "notify"
                iconSize: 18
                color: Theme.accentIcon
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: alertPopup.heading
                color: Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
                font.weight: 700
            }

            Text {
                Layout.fillWidth: true
                text: alertPopup.label
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.valueSize
                font.weight: 600
            }
        }

        ActionButton {
            label: "OK"
            onActivated: alertPopup.forceClose()
        }
    }
}
