import QtQuick

import qs.Objects.Theme
import qs.Objects.Systems

Rectangle {
    id: panel

    required property string name
    required property var owner

    readonly property var windows: HyprlandSystem.windowsOnSpecial(name)

    // A special workspace lives on one monitor at a time, so its windows share
    // that monitor's coordinate frame. If the monitor is gone, fall back to the
    // bounding box of the windows themselves.
    readonly property var frame: {
        if (windows.length === 0)
            return { x: 0, y: 0, w: 16, h: 9 }

        var mon = HyprlandSystem.monitorByName(windows[0].monitor)
        if (mon && mon.w > 0 && mon.h > 0)
            return { x: mon.x, y: mon.y, w: mon.w, h: mon.h }

        var minX = windows[0].x
        var minY = windows[0].y
        var maxX = windows[0].x + windows[0].w
        var maxY = windows[0].y + windows[0].h
        for (var i = 1; i < windows.length; i++) {
            minX = Math.min(minX, windows[i].x)
            minY = Math.min(minY, windows[i].y)
            maxX = Math.max(maxX, windows[i].x + windows[i].w)
            maxY = Math.max(maxY, windows[i].y + windows[i].h)
        }
        return { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
    }

    readonly property real mapHeight: 150
    readonly property real mapWidth: Math.round(mapHeight * (frame.w / frame.h))
    readonly property real scaleFactor: frame.w > 0 ? (mapWidth / frame.w) : 1

    implicitWidth: Math.max(mapWidth, 210) + 24
    implicitHeight: mapHeight + list.implicitHeight + 54

    radius: Theme.radius
    color: Theme.alpha(Theme.scrimBase, 0.94)
    border.width: Theme.borderWidth
    border.color: Theme.borderStrong

    Text {
        id: heading
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 12
        text: (panel.owner ? panel.owner.bucketLabel(panel.name) : panel.name)
            + "  ·  " + panel.windows.length + " windows"
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: 600
    }

    // ## Minimap
    // Real geometry, letters only — a stashed window is not being rendered by
    // the compositor, so there is no frame to capture.

    Rectangle {
        id: map
        anchors.top: heading.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: panel.mapWidth
        height: panel.mapHeight
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.scrimBase, 0.6)
        border.width: Theme.borderWidth
        border.color: Theme.border
        clip: true

        Repeater {
            model: panel.windows

            delegate: Rectangle {
                required property var modelData

                x: Math.round((modelData.x - panel.frame.x) * panel.scaleFactor)
                y: Math.round((modelData.y - panel.frame.y) * panel.scaleFactor)
                width: Math.max(8, Math.round(modelData.w * panel.scaleFactor))
                height: Math.max(8, Math.round(modelData.h * panel.scaleFactor))

                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.scrimBase, 0.45)
                border.width: Theme.borderWidth
                border.color: Theme.alpha(Theme.textBase, 0.12)

                Text {
                    anchors.centerIn: parent
                    text: modelData.appClass ? modelData.appClass.charAt(0).toUpperCase() : "?"
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.weight: 700
                    font.pixelSize: Math.max(9, Math.min(parent.height * 0.4, 20))
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "empty"
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: 11
            visible: panel.windows.length === 0
        }
    }

    // ## Contents

    Column {
        id: list
        anchors.top: map.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 3

        Repeater {
            model: panel.windows.slice(0, 6)

            delegate: Row {
                required property var modelData
                spacing: 6

                Text {
                    text: modelData.appClass
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: 600
                }

                Text {
                    width: Math.max(0, list.width - 90)
                    text: modelData.title
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            visible: panel.windows.length > 6
            text: "+" + (panel.windows.length - 6) + " more"
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
