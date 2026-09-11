import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

Rectangle {
    id: chip

    required property string widgetId
    required property int chipIndex
    required property var owner
    property string zoneKey: ""
    property bool dimmed: false

    readonly property var meta: owner.meta(widgetId)

    width: label.implicitWidth + 40
    height: 30
    radius: Theme.radiusSmall
    opacity: dimmed ? 0.35 : 1.0

    color: area.containsMouse ? Theme.alpha(Theme.accent, 0.20)
                              : Theme.alpha(Theme.textBase, 0.10)
    border.width: Theme.borderWidth
    border.color: area.containsMouse ? Theme.accentLine : Theme.border

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

    Icon {
        id: chipIcon
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        iconName: chip.meta.icon
        iconSize: 14
        color: Theme.accentIcon
    }

    Text {
        id: label
        anchors.left: chipIcon.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: chip.meta.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.valueSize
        font.weight: 600
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true

        // The settings pages sit in a ScrollView. Without this the Flickable
        // steals the grab the moment the pointer moves and the drag is
        // cancelled before it has begun.
        preventStealing: true
        cursorShape: chip.dimmed && chip.zoneKey === ""
            ? Qt.ArrowCursor : Qt.OpenHandCursor

        property bool armed: false
        property point origin

        onPressed: (mouse) => {
            if (chip.dimmed && chip.zoneKey === "")
                return
            area.armed = true
            area.origin = Qt.point(mouse.x, mouse.y)
        }

        onPositionChanged: (mouse) => {
            if (!area.armed)
                return

            var moved = Math.abs(mouse.x - area.origin.x)
                + Math.abs(mouse.y - area.origin.y)
            var point = chip.mapToItem(chip.owner, mouse.x, mouse.y)

            if (chip.owner.dragId === "") {
                if (moved < 6)
                    return
                chip.owner.beginDrag(chip.widgetId, chip.zoneKey, chip.chipIndex, point)
            } else {
                chip.owner.updateDrag(point)
            }
        }

        onReleased: {
            area.armed = false
            if (chip.owner.dragId !== "")
                chip.owner.endDrag()
        }

        onCanceled: {
            area.armed = false
            chip.owner.cancelDrag()
        }
    }
}
