import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

Rectangle {
    id: tile

    property string iconName: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool enabled: true
    signal activated()

    implicitHeight: 62
    radius: Theme.radius
    opacity: enabled ? 1.0 : 0.45

    color: active ? Theme.alpha(Theme.accent, 0.30)
                  : Theme.alpha(Theme.textBase, 0.09)
    border.width: Theme.borderWidth
    border.color: active ? Theme.accent : Theme.border

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

    Icon {
        id: tileIcon
        visible: tile.iconName !== ""
        iconName: tile.iconName !== "" ? tile.iconName : "settings"
        iconSize: 20
        color: tile.active ? Theme.accentText : Theme.textDim
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
    }

    Column {
        anchors.left: tileIcon.visible ? tileIcon.right : parent.left
        anchors.leftMargin: tileIcon.visible ? 10 : 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: tile.label
            elide: Text.ElideRight
            color: tile.active ? Theme.accentText : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.labelSize
            font.weight: 600
        }

        Text {
            width: parent.width
            visible: tile.sublabel !== ""
            text: tile.sublabel
            elide: Text.ElideRight
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.alpha(Theme.textBase, 0.07)
        visible: tileArea.containsMouse
    }

    MouseArea {
        id: tileArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.activated()
    }
}
