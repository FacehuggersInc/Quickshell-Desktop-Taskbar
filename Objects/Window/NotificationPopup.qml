import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets

PopupWindow {
    id: popup
    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height
    implicitWidth: 420
    implicitHeight: display.implicitHeight > 0 ? display.implicitHeight : 80
    color: "transparent"
    visible: false

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

    RowLayout {
        width: popup.width
        height: display.implicitHeight

        Notification {
            id: display
            notification: popup.notification
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
        }
    }

    function setPopupIcon(iconName) {
        display.setIcon(iconName)
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