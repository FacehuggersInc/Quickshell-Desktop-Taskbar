import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// A small read-only panel. Same surface language as the controls, at a smaller
// size, so a piece of information reads as related to them without looking
// like something you can switch.
Rectangle {
    id: stat

    property string iconName: ""
    property string caption: ""
    property string value: ""
    property bool interactive: false
    signal activated()

    Layout.fillWidth: true
    Layout.minimumWidth: 140
    Layout.preferredHeight: 52

    radius: Theme.radiusSmall
    color: (stat.interactive && statArea.containsMouse)
        ? Theme.alpha(Theme.accent, 0.16)
        : Theme.alpha(Theme.textBase, 0.06)
    border.width: Theme.borderWidth
    border.color: Theme.alpha(Theme.textBase, 0.10)

    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Icon {
        id: statIcon
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        visible: stat.iconName !== ""
        iconName: stat.iconName
        iconSize: 17
        color: Theme.accentIcon
    }

    Column {
        anchors.left: statIcon.visible ? statIcon.right : parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            width: parent.width
            text: stat.caption
            elide: Text.ElideRight
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: 700
            font.letterSpacing: 0.8
        }

        Text {
            width: parent.width
            text: stat.value
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.valueSize
            font.weight: 600
        }
    }

    MouseArea {
        id: statArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: stat.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: stat.activated()
    }
}
