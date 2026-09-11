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
    anchor.rect.y: mainWindow.popupOffset(implicitHeight)
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
                return
            }

            // Track the content from here on. The animation target was a
            // snapshot, and a menu built by a Repeater is still empty when the
            // reveal starts, so the panel stayed shorter than its rows.
            display.height = Qt.binding(function() { return popup.implicitHeight })
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

        // The grab was taken but never acted on, so clicking away released it
        // and left the popup sitting there
        onCleared: {
            if (popup.requireFocusGrab && popup.visible && !popup.isClosing)
                popup.forceClose()
        }
    }

    required property var content

    RoundedBlock {
        id: display
        alpha: 0
        height: 0
        radius: Theme.radius
        implicitWidth: popup.implicitWidth
        color: Theme.panelScrim

        // The specular top run reads as a stray white line on a small panel
        highlight: false
        sidePadding: popup.sidePadding
        tbPadding: popup.tbPadding
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

    // Opens centred on a point rather than on a widget, clamped so it cannot
    // run off either edge of the screen
    function forceOpenAt(x) {
        popup.pendingX = x
        popup.openAtPoint = true
        popup.forceOpen(null)
        popup.openAtPoint = false
    }

    property real pendingX: 0
    property bool openAtPoint: false

    function forceOpen(widget) {
        heightAnim.stop()
        alphaAnim.stop()
        popup.shouldHide = false
        popup.isClosing = false

        if (popup.openAtPoint) {
            var limit = mainWindow.width - popup.implicitWidth - 8
            popup.anchor.rect.x = Math.max(8,
                Math.min(limit, popup.pendingX - popup.implicitWidth / 2))
        } else if (widget) {
            updatePopupPosition(widget)
        }

        // Zero out before mapping so compositor gets a clean first frame
        display.alpha = 0
        display.height = 0
        content.visible = true
        popup.visible = true

        alphaAnim.from = 0
        alphaAnim.to = fadingEffectMax
        alphaAnim.start()

        // Height was a snapshot taken at open time. A menu whose rows are built
        // by a Repeater is still empty at that moment, so the panel ended up
        // shorter than its content and clipped it.
        if (scrollingEffect) {
            heightAnim.from = 0
            heightAnim.to = popup.implicitHeight
            heightAnim.start()
        } else {
            display.height = Qt.binding(function() { return popup.implicitHeight })
        }

        popup.open()
        if (requireFocusGrab) grabFocus.running = true
    }

    function forceClose() {
        // Drop the tracking binding so the close animation can drive height
        display.height = display.height

        grabFocus.running = false
        focusGrab.active = false

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
    }

    function toggle(widget) {
        if (!popup.visible || popup.isClosing) {
            forceOpen(widget)
        } else {
            forceClose()
        }
    }
}