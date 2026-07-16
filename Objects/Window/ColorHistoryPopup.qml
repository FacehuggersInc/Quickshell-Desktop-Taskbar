import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets

PopupWindow {
    id: colorHistoryPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth: 220
    property int panelHeight: 155

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property bool isClosing: false

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (colorHistoryPopup.isClosing) {
                colorHistoryPopup.visible = false
                colorHistoryPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ colorHistoryPopup ]
        onCleared: {
            alphaAnim.stop()
            colorHistoryPopup.isClosing = false
            colorHistoryPopup.visible = false
            background.opacity = 0
        }
    }

    // Process lives outside Rectangle so it doesn't affect layout
    Process {
        id: clearColorProc
        command: root.newUtill(["--clearcolors"])
        stdout: StdioCollector {
            onStreamFinished: {
                root.settings.colorHistory = []
                root.saveSettings()
            }
        }
    }

    Rectangle {
        id: background
        width: panelWidth
        height: panelHeight
        radius: 12
        // Use surface not background — higher alpha so it's clearly opaque
        color: root.settings.theme.surface
        opacity: 0
        clip: true

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 1
            verticalOffset: 2
            radius: 16
            samples: 32
            color: "#aa000000"
            source: background
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            anchors.topMargin: 8
            spacing: 6

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Color History"
                    color: root.settings.theme.text
                    font.family: root.settings.fontFamily
                    font.weight: 700
                    font.pixelSize: 12
                    opacity: 0.7
                    Layout.fillWidth: true
                }
                IconButton {
                    iconName: "delete"
                    iconSize: 14
                    color: "#e05555"
                    tooltipText: "Clear history"
                    onClicked: clearColorProc.running = true
                }
            }

            // 5 per row grid
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.settings.colorHistory || []
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: 34
                        height: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: modelData
                            border.color: colorHov.hovered
                                ? root.settings.theme.text
                                : Qt.rgba(1,1,1,0.15)
                            border.width: colorHov.hovered ? 2 : 1

                            Behavior on border.width { NumberAnimation { duration: 80 } }
                        }

                        HoverHandler { id: colorHov; cursorShape: Qt.PointingHandCursor }

                        Tooltip { id: colorTooltip; text: modelData }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.clipboardText = modelData
                                colorHistoryPopup.forceClose()
                            }
                            HoverHandler {
                                onHoveredChanged: colorTooltip.toggleOnTo(point)
                            }
                        }
                    }
                }

                // Empty state
                Text {
                    visible: !root.settings.colorHistory
                        || root.settings.colorHistory.length === 0
                    text: "No colors yet"
                    color: root.settings.theme.text
                    opacity: 0.4
                    font.family: root.settings.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        colorHistoryPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) { alphaAnim.stop(); isClosing = false }
        updatePosition(widget)
        background.opacity = 0
        colorHistoryPopup.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
        focusGrab.active = false
    }

    function toggle(widget) {
        if (!colorHistoryPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}