import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

Rectangle {
    id: button

    property string label: ""
    property string iconName: ""
    // neutral | accent | danger
    property string tone: "neutral"
    property bool busy: false
    signal activated()

    readonly property color toneColor: tone === "danger" ? Theme.danger
        : tone === "accent" ? Theme.accent : Theme.textBase

    implicitWidth: Math.max(72, content.implicitWidth + 24)
    implicitHeight: Theme.controlHeight
    radius: Theme.radiusSmall
    opacity: enabled ? 1.0 : 0.4

    color: area.containsMouse && enabled
        ? Theme.alpha(toneColor, tone === "neutral" ? 0.16 : 0.24)
        : Theme.alpha(Theme.textBase, 0.10)

    border.width: Theme.borderWidth
    border.color: tone === "accent" && !busy ? Theme.accentLine : Theme.border

    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: button.busy || button.iconName !== ""
            iconName: button.busy ? "sync" : (button.iconName !== "" ? button.iconName : "sync")
            iconSize: 14
            color: button.tone === "danger" && area.containsMouse
                ? Theme.danger : Theme.textDim
            anchors.verticalCenter: parent.verticalCenter

            RotationAnimation on rotation {
                running: button.busy
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1000
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: button.label
            color: button.tone === "danger" && area.containsMouse ? Theme.danger : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.valueSize
            font.weight: 600
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: !button.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
