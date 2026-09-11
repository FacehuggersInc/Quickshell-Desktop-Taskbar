import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets
import qs.Objects.Theme

PopupWindow {
    id: networkPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.popupOffset(implicitHeight)

    property int panelWidth:  320
    property int panelHeight: 220

    implicitWidth:  panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property Region glassBlurRegion: Region { item: background }
    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? glassBlurRegion : null

    MouseArea { anchors.fill: parent; z: -1; onClicked: networkPopup.forceClose() }

    property bool isClosing: false

    // ## Back
    // Set when the quick panel opened this, so there is a way to return

    property var backTarget: null

    function goBack() {
        var target = networkPopup.backTarget
        networkPopup.backTarget = null
        networkPopup.forceClose()
        if (target && mainWindow.settingsAnchor)
            target.forceOpen(mainWindow.settingsAnchor)
    }


    // Parsed network state
    property string netInterface: "..."
    property string netType:      "unknown"
    property string netVpn:       "no"
    property int    netRxSpeed:   0
    property int    netTxSpeed:   0

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (networkPopup.isClosing) {
                networkPopup.visible = false
                networkPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ networkPopup ]
        onCleared: networkPopup.forceClose()
    }

    Process {
        id: netInfoProc
        command: root.newUtill(["--getnetworkinfo"])
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length < 7) return
                networkPopup.netInterface = parts[0]
                networkPopup.netType      = parts[1]
                networkPopup.netVpn       = parts[2]
                networkPopup.netRxSpeed   = parseInt(parts[5]) || 0
                networkPopup.netTxSpeed   = parseInt(parts[6]) || 0
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1500
        repeat: true
        running: false
        onTriggered: { if (!netInfoProc.running) netInfoProc.running = true }
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024)        return bytesPerSec + " B/s"
        if (bytesPerSec < 1048576)     return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        if (bytesPerSec < 1073741824)  return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
        return (bytesPerSec / 1073741824).toFixed(2) + " GB/s"
    }

    Rectangle {
        id: background

        // Back to quick settings
        Rectangle {
            visible: networkPopup.backTarget !== null
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8
            width: backLabel.implicitWidth + 22
            height: 24
            radius: Theme.radiusSmall
            z: 50
            color: backArea.containsMouse ? Theme.alpha(Theme.accent, 0.24)
                                          : Theme.alpha(Theme.textBase, 0.12)
            border.width: Theme.borderWidth
            border.color: Theme.border

            Text {
                id: backLabel
                anchors.centerIn: parent
                text: "\u2190 Quick Settings"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: 600
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: networkPopup.goBack()
            }
        }
        width: panelWidth
        height: panelHeight
        radius: 15
        color: root.theme.background
        border.width: Theme.borderWidth
        border.color: Theme.border
        opacity: 0
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.7
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
            blurMax: 24
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            // Pushed clear of the back control rather than sitting under it
            anchors.topMargin: networkPopup.backTarget !== null ? 42 : 16
            spacing: 12

            // ── Connection type + interface ───────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                IconButton {
                    iconName: networkPopup.netType === "wired"    ? "wired"
                            : networkPopup.netType === "wireless" ? "wifi_max"
                            : "wired"
                    iconSize: 32
                    color: root.theme.primary
                    tooltipText: networkPopup.netType
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: networkPopup.netInterface
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 700
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: networkPopup.netType === "wired"    ? "Wired connection"
                            : networkPopup.netType === "wireless" ? "Wireless connection"
                            : "Network connection"
                        color: root.theme.text
                        opacity: 0.5
                        font.family: root.settings.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.theme.text
                opacity: 0.08
            }

            // ── VPN ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                IconButton {
                    iconName: "vpn"
                    iconSize: 20
                    color: networkPopup.netVpn !== "no"
                        ? root.theme.primary
                        : root.theme.text
                    opacity: networkPopup.netVpn !== "no" ? 1.0 : 0.3
                    tooltipText: "VPN"
                }

                Text {
                    text: networkPopup.netVpn !== "no"
                        ? "VPN: " + networkPopup.netVpn
                        : "No VPN"
                    color: root.theme.text
                    opacity: networkPopup.netVpn !== "no" ? 1.0 : 0.4
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
            }

            // ── Download / Upload speeds ──────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                // Download
                RowLayout {
                    spacing: 6
                    Icon {
    iconName: "download"
    iconSize: 16
    color: Theme.accentIcon
    opacity: 0.6
}
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Download"
                            color: root.theme.text
                            opacity: 0.5
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: networkPopup.formatSpeed(networkPopup.netRxSpeed)
                            color: root.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 600
                            font.pixelSize: 14
                        }
                    }
                }

                Rectangle { width: 1; height: 30; color: root.theme.text; opacity: 0.1 }

                // Upload
                RowLayout {
                    spacing: 6
                    Icon {
    iconName: "upload"
    iconSize: 16
    color: Theme.accentIcon
    opacity: 0.6
}
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Upload"
                            color: root.theme.text
                            opacity: 0.5
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: networkPopup.formatSpeed(networkPopup.netTxSpeed)
                            color: root.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 600
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }

    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        networkPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) { alphaAnim.stop(); isClosing = false }
        updatePosition(widget)
        background.opacity = 0
        networkPopup.visible = true
        alphaAnim.from = 0; alphaAnim.to = 1.0; alphaAnim.start()
        focusGrab.active = true
        if (!netInfoProc.running) netInfoProc.running = true
        refreshTimer.start()
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity; alphaAnim.to = 0; alphaAnim.start()
        focusGrab.active = false
        refreshTimer.stop()
    }

    function toggle(widget) {
        // Opened from the bar, so there is nothing to go back to
        networkPopup.backTarget = null
        if (!networkPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}