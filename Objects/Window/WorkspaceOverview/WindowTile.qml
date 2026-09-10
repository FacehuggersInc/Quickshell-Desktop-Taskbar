import QtQuick
import Quickshell.Wayland
import Quickshell.Widgets

import qs.Objects.Theme

Rectangle {
    id: tile

    required property var win
    required property var owner
    property bool interactive: true

    property bool dragging: owner ? owner.dragAddress === win.address : false
    property bool active: win.activated

    radius: Theme.radiusSmall
    // Sinking these into the monitor rather than lifting them off it — a light
    // fill over a dark tile reads as grey blocks once previews are in play
    color: active ? Theme.alpha(Theme.accent, 0.22)
                  : Theme.alpha(Theme.scrimBase, 0.45)
    border.width: Theme.borderWidth
    border.color: active ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.12)
    opacity: dragging ? 0.25 : 1.0

    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    // ## Preview
    // Hyprland only renders the active workspace, so a stashed window has
    // nothing to capture and always falls through to the letter.

    readonly property bool previewable:
        Theme.previewMode !== "off"
        && win.wayland !== null
        && !win.special
        && width > 26 && height > 20

    property bool previewReady: false

    // ClippingRectangle clips to a rounded rect, which plain QtQuick clip does
    // not — it is rectangular only, so the capture would square off the corners
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, tile.radius - 1)
        color: "transparent"

        Loader {
            anchors.fill: parent
            active: tile.previewable
            visible: tile.previewReady && !tile.dragging

            sourceComponent: ScreencopyView {
                captureSource: tile.win.wayland
                live: Theme.previewMode === "live"
                paintCursor: false

                onHasContentChanged: tile.previewReady = hasContent

                // A capture issued before the compositor has a recording
                // context just warns and does nothing, so the first one waits
                // for the view to settle rather than firing on completion
                Timer {
                    id: firstCapture
                    interval: 160
                    repeat: false
                    running: true
                    onTriggered: {
                        if (!parent.live) parent.captureFrame()
                    }
                }

                Connections {
                    target: tile.owner
                    function onPreviewTick() {
                        if (!live) captureFrame()
                    }
                }
            }
        }
    }

    // ## Label
    // Shown until a frame arrives, and permanently for stashed windows

    Text {
        anchors.centerIn: parent
        text: tile.win.appClass ? tile.win.appClass.charAt(0).toUpperCase() : "?"
        color: tile.active ? Theme.accentText : Theme.textMute
        font.family: Theme.fontFamily
        font.weight: 700
        font.pixelSize: Math.max(9, Math.min(parent.height * 0.45, 22))
        visible: !tile.previewReady && parent.width > 18 && parent.height > 16
    }

    Rectangle {
        visible: tile.win.floating && parent.width > 26
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: 4
        height: 4
        radius: 2
        color: Theme.textMute
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.interactive
        visible: tile.interactive
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        property bool armed: false
        property point origin

        onPressed: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return
            armed = true
            origin = Qt.point(mouse.x, mouse.y)
        }

        onPositionChanged: (mouse) => {
            if (!armed) return
            var moved = Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y)
            var point = tile.mapToItem(owner.dragLayer, mouse.x, mouse.y)

            if (!tile.dragging) {
                if (moved < 6) return
                owner.beginDrag(tile.win, point)
            } else {
                owner.updateDrag(point)
            }
        }

        onReleased: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return
            armed = false
            if (tile.dragging) {
                owner.endDrag(tile.mapToItem(owner.dragLayer, mouse.x, mouse.y))
            } else {
                owner.focusWindow(tile.win)
            }
        }

        onCanceled: {
            armed = false
            owner.cancelDrag()
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                owner.closeWindow(tile.win)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.alpha(Theme.textBase, 0.10)
        visible: area.containsMouse && !tile.dragging
    }
}
