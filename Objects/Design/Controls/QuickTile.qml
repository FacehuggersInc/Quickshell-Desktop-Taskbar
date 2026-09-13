import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

Rectangle {
    id: tile

    property string iconName: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false

    // A toggle keeps a state; an action just fires. They looked identical,
    // so there was no way to tell which a tile was until you pressed it.
    property bool toggle: false
    signal activated()

    // Square, with the icon centred and the label beneath. The side matches a
    // PanelRow's height so a grid of tiles lines up with the rows above it.
    implicitHeight: 52
    radius: Theme.radiusSmall
    opacity: enabled ? 1.0 : 0.45

    // Filled when on, outlined when off — the same rule the rows follow
    // A toggle that is on is filled outright. An action never fills — it
    // carries the arrow instead — so the two are told apart by the surface.
    color: active ? Theme.alpha(Theme.accent, 0.55)
        : (tileArea.containsMouse ? Theme.alpha(Theme.accent, 0.12)
                                  : Theme.alpha(Theme.scrimBase, 0.35))
    border.width: Theme.borderWidth
    border.color: active ? Theme.accent : Theme.alpha(Theme.textBase, 0.10)

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

    // Actions carry an arrow instead
    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.rightMargin: 8
        visible: !tile.toggle
        text: "\u2197"
        color: tileArea.containsMouse ? Theme.accentText : Theme.alpha(Theme.textBase, 0.30)
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Column {
        anchors.centerIn: parent

        spacing: 3

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: tile.iconName !== ""
            iconName: tile.iconName !== "" ? tile.iconName : "settings"
            iconSize: 18
            color: tile.active ? Theme.onAccent : Theme.textDim
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            color: tile.active ? Theme.onAccent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
            font.weight: 600
        }
    }

    MouseArea {
        id: tileArea
        anchors.fill: parent
        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor
        onClicked: tile.activated()
    }
}
