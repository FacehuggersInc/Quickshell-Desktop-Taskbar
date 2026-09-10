import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell.Hyprland

import qs.Objects.Design
import qs.Objects.Theme

PopupWindow {
    id: popup
    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5
    implicitWidth: 350
    implicitHeight: 450
    color: "transparent"
    visible: false

    // Mask the window to exactly the display rect so the compositor
    // never sees pixels outside the animated block (prevents ghost frames)
    mask: Region {
        item: display
    }

    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? display.blurRegion : null

    property int sidePadding: 0
    property int tbPadding: 0

    signal open()
    signal close()

    property bool requireFocusGrab: false
    property bool scrollingEffect: true
    property double fadingEffectMax: 1.0
    property bool shouldHide: false
    property bool isClosing: false

    property PropertyAnimation heightAnim: PropertyAnimation {
        id: heightAnim
        target: display
        property: "height"
        from: 0
        to: popup.implicitHeight
        duration: 150
        onFinished: {
            if (popup.shouldHide) {
                popup.visible = false
                popup.shouldHide = false
                popup.isClosing = false
                display.alpha = 0
                display.height = 0
            }
        }
    }

    property PropertyAnimation alphaAnim: PropertyAnimation {
        id: alphaAnim
        target: display
        property: "alpha"
        from: 0
        to: fadingEffectMax
        duration: 150
        onFinished: {
            if (!scrollingEffect && popup.shouldHide) {
                popup.visible = false
                popup.shouldHide = false
                popup.isClosing = false
                display.alpha = 0
            }
        }
    }

    Timer {
        id: grabFocus
        interval: 100
        onTriggered: {
            focusGrab.active = !focusGrab.active
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ popup ]
    }

    required property var content

    RoundedBlock {
        id: display
        alpha: 0
        height: 0
        radius: Theme.radius
        implicitWidth: popup.implicitWidth
        color: Theme.panelScrim
        sidePadding: sidePadding
        tbPadding: tbPadding
        clip: true
        LayoutItemProxy {
            target: content
            width: display.width
            anchors.left: parent.left
            anchors.right: parent.right
        }
    }

    function updatePopupPosition(widget) {
        let position = mainWindow.itemPosition(widget)
        popup.anchor.rect.x = (position.x + (widget.width / 2)) - (popup.width / 2)
    }

    function forceOpen(widget) {
        heightAnim.stop()
        alphaAnim.stop()
        popup.shouldHide = false
        popup.isClosing = false

        updatePopupPosition(widget)

        // Zero out before mapping so compositor gets a clean first frame
        display.alpha = 0
        display.height = 0
        content.visible = true
        popup.visible = true

        alphaAnim.from = 0
        alphaAnim.to = fadingEffectMax
        alphaAnim.start()

        if (scrollingEffect) {
            heightAnim.from = 0
            heightAnim.to = popup.implicitHeight
            heightAnim.start()
        } else {
            display.height = popup.implicitHeight
        }

        popup.open()
        if (requireFocusGrab) grabFocus.running = true
    }

    function forceClose() {
        if (popup.isClosing) return
        popup.isClosing = true
        popup.shouldHide = true

        heightAnim.stop()
        alphaAnim.stop()

        alphaAnim.from = display.alpha
        alphaAnim.to = 0
        alphaAnim.start()

        if (scrollingEffect) {
            heightAnim.from = display.height
            heightAnim.to = 0
            heightAnim.start()
        }

        content.visible = false
        popup.close()
        if (requireFocusGrab) grabFocus.running = true
    }

    function toggle(widget) {
        if (!popup.visible || popup.isClosing) {
            forceOpen(widget)
        } else {
            forceClose()
        }
    }
}