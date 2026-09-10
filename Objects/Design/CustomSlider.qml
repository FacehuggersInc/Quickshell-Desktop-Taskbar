import QtQuick
import QtQuick.Controls

Slider {
    id: slider

    property int trackHeight: 6
    property int trackRadius: 3
    property int handleRadius: 10
    property int handleBorderWidth: 1
    property int handleSize: 15
    property string trackColor: root.theme.surface
    property string progressColor: root.theme.primary
    property string handleColor: root.theme.primary
    property string handleBorderColor: root.theme.primary

    // --- TRACK (background) ---
    background: Item {
        implicitHeight: trackHeight
        width: parent.width

        // Unfilled track
        Rectangle {
            anchors.fill: parent
            color: trackColor
            radius: trackRadius
        }

        // Filled portion
        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            color: progressColor
            radius: trackRadius
        }
    }

    handle: Rectangle {
        width: handleSize
        height: handleSize
        radius: handleRadius
        color: handleColor
        border.color: handleBorderColor
        border.width: handleBorderWidth

        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2

        HoverHandler {
            id:hoverHandler
            cursorShape: Qt.PointingHandCursor
        }
    }
}