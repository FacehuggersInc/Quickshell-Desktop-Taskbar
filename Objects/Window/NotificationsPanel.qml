import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland

import qs.Objects.Design
import qs.Objects.Widgets

PopupWindow {
    id: notificationsPanel

    anchor.window: mainWindow
    anchor.rect.x: Screen.width
    anchor.rect.y: mainWindow.height + 5

    // Width is fixed; height fits content up to screen height
    implicitWidth: 400
    implicitHeight: Math.min(
        headerRow.implicitHeight + 16 + 1 + 8 + notifColumn.implicitHeight + 24,
        Screen.height - mainWindow.height - 10
    )

    color: "transparent"
    visible: false

    mask: Region { item: panelBackground }

    property bool isOpen: false
    property bool isAnimating: false

    PropertyAnimation {
        id: slideAnim
        target: panelBackground
        property: "x"
        duration: 220
        easing.type: Easing.InOutQuad
        onFinished: {
            notificationsPanel.isAnimating = false
            if (!notificationsPanel.isOpen) {
                notificationsPanel.visible = false
                panelBackground.x = notificationsPanel.implicitWidth
            }
        }
    }

    PropertyAnimation {
        id: alphaAnim
        target: panelBackground
        property: "alpha"
        duration: 220
        easing.type: Easing.InOutQuad
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ notificationsPanel ]
        onCleared: {
            // Always close regardless of animation state
            if (notificationsPanel.isAnimating) {
                slideAnim.stop()
                alphaAnim.stop()
                notificationsPanel.isAnimating = false
            }
            notificationsPanel.isOpen = false
            notificationsPanel.visible = false
            panelBackground.x = notificationsPanel.implicitWidth
            panelBackground.alpha = 0
            focusGrab.active = false
        }
    }

    RoundedBlock {
        id: panelBackground
        width: notificationsPanel.implicitWidth
        height: notificationsPanel.implicitHeight
        alpha: 0
        x: notificationsPanel.implicitWidth
        y: 0
        radius: 12
        color: root.settings.theme.background
        sidePadding: 0
        tbPadding: 0
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header ────────────────────────────────────────────
            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 8
                spacing: 8

                Text {
                    text: "Notifications"
                    color: root.settings.theme.text
                    font.family: root.settings.fontFamily
                    font.weight: 700
                    font.pixelSize: 20
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: root.notifyServer.trackedNotifications.values.length > 0
                    width: countText.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: root.settings.theme.primary
                    opacity: 0.8

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.notifyServer.trackedNotifications.values.length
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 700
                        font.pixelSize: 13
                    }
                }

                RoundButton {
                    visible: root.notifyServer.trackedNotifications.values.length > 0
                    text: "Clear all"
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    padding: 5
                    horizontalPadding: 10
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: root.settings.theme.text
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: "#e05555"
                        opacity: 0.7
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    onClicked: {
                        var notifs = root.notifyServer.trackedNotifications.values
                        for (var i = notifs.length - 1; i >= 0; i--) {
                            notifs[i].dismiss()
                        }
                    }
                }

                IconButton {
                    iconName: "close"
                    iconSize: 20
                    color: root.settings.theme.text
                    tooltipText: "Close"
                    onClicked: notificationsPanel.close()
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                height: 1
                color: root.settings.theme.text
                opacity: 0.1
            }

            // ── Notification list ─────────────────────────────────
            ScrollView {
                id: notifScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                contentHeight: notifColumn.implicitHeight
                contentWidth: notificationsPanel.implicitWidth - 32

                ColumnLayout {
                    id: notifColumn
                    width: notificationsPanel.implicitWidth - 32
                    spacing: 8
                    x: 16

                    // Empty state
                    Text {
                        visible: root.notifyServer.trackedNotifications.values.length === 0
                        text: "No notifications"
                        color: root.settings.theme.text
                        opacity: 0.4
                        font.family: root.settings.fontFamily
                        font.pixelSize: 16
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 24
                    }

                    Repeater {
                        model: root.notifyServer.trackedNotifications
                        delegate: Notification {
                            required property var modelData
                            Layout.fillWidth: true
                            notification: modelData
                        }
                    }

                    Item { implicitHeight: 8 }
                }
            }
        }
    }

    function open() {
        if (isOpen || isAnimating) return
        isOpen = true
        isAnimating = true

        notificationsPanel.anchor.rect.x = Screen.width - notificationsPanel.implicitWidth - 8
        panelBackground.x = notificationsPanel.implicitWidth
        panelBackground.alpha = 0
        notificationsPanel.visible = true

        slideAnim.from = notificationsPanel.implicitWidth
        slideAnim.to   = 0
        slideAnim.start()

        alphaAnim.from = 0
        alphaAnim.to   = 1.0
        alphaAnim.start()

        focusGrab.active = true
    }

    function close() {
        if (!isOpen) return
        // If already animating close, let it finish
        if (isAnimating) return
        isOpen = false
        isAnimating = true

        slideAnim.from = 0
        slideAnim.to   = notificationsPanel.implicitWidth
        slideAnim.start()

        alphaAnim.from = 1.0
        alphaAnim.to   = 0
        alphaAnim.start()

        focusGrab.active = false
    }

    function toggle() {
        if (isOpen) close()
        else open()
    }
}