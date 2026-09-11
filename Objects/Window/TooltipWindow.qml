import QtQuick
import Quickshell
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

import qs.Objects.Design
import qs.Objects.Theme

// Singleton PopupWindow for tooltips — lives directly in MainWindow
// so it can anchor correctly without being nested inside other items
PopupWindow {
    id: tooltipWindow

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.popupOffset(implicitHeight - 1)

    implicitWidth:  tooltipLabel.implicitWidth + 20
    implicitHeight: 26
    color: "transparent"
    visible: false

    mask: Region { item: bg }

    property Region glassBlurRegion: Region { item: bg }
    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? glassBlurRegion : null

    Rectangle {
        id: bg
        width:  tooltipWindow.implicitWidth
        height: tooltipWindow.implicitHeight
        radius: 6
        color:  root.theme.surface

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            color: root.theme.text
            font.family: root.settings.fontFamily
            font.pixelSize: 13
            font.weight: 500
        }
    }

    function show(txt, absX) {
        tooltipLabel.text = txt
        // Force width recalculation before positioning
        var w = tooltipLabel.implicitWidth + 20
        var x = absX - w / 2
        x = Math.max(0, Math.min(x, Screen.width - w))
        tooltipWindow.anchor.rect.x = x
        tooltipWindow.visible = true
    }

    function hide() {
        tooltipWindow.visible = false
    }
}