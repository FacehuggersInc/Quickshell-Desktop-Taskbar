import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Theme

PopupWindow {
    id: popup
    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.popupOffset(implicitHeight)
    implicitWidth: 420
    implicitHeight: display.implicitHeight > 0 ? display.implicitHeight : 80
    color: "transparent"
    visible: false

    // Toasts had no mask, so the pass that added blur to every popup skipped
    // this one. RoundedBlock exposes a region that follows its rounded corners.
    mask: Region { item: display }

    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? display.blurRegion : null

    // Accept the full notification object instead of loose strings
    property var notification: null

    // Keep these for compatibility with any callers that still set them,
    // but they are ignored if notification is set
    property string title: ""
    property string body: ""
    property string icon: ""

    property bool shouldHide: false

    PropertyAnimation {
        id: anim
        target: display
        property: "alpha"
        from: 0
        to: 1.0
        duration: 300
        onFinished: {
            if (popup.visible && popup.shouldHide) {
                popup.visible = false
                display.alpha = 0
                popup.notification = null
            }
        }
    }

    Timer {
        id: timeout
        interval: 6000
        running: false
        onTriggered: popup.toggle()
    }

    Item {
        width: popup.implicitWidth
        height: display.implicitHeight

        Notification {
            id: display
            anchors.left: parent.left
            anchors.right: parent.right
            notification: popup.notification
        }
    }

    function setPopupIcon(iconName) {
        // Icon resolution lives in Notification now
    }

    function updatePopupPosition() {
        var x = mainWindow.contentItem.x + ((Screen.width / 2) - (popup.width / 2))
        popup.anchor.rect.x = x
    }

    function animateAlpha(from, to) {
        anim.from = from
        anim.to   = to
        anim.start()
    }

    function toggle() {
        updatePopupPosition()
        if (popup.visible) {
            popup.shouldHide = true
            animateAlpha(1.0, 0)
        } else {
            popup.shouldHide = false
            popup.visible    = true
            animateAlpha(0, 1.0)
            timeout.restart()
        }
    }
}