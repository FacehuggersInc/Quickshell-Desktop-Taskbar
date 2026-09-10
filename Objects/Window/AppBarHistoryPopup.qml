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
import qs.Objects.Widgets
import qs.Objects.Window
import qs.Objects.Theme

PopupWindow {
    id: historyPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth: 420
    property int panelHeight: Math.min(Screen.height - mainWindow.height - 20, 500)

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property Region glassBlurRegion: Region { item: background }
    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? glassBlurRegion : null

    property bool isClosing: false
    property var commands: []
    property string searchQuery: ""

    property var filteredCommands: {
        if (!searchQuery || searchQuery.trim() === "") return commands
        var q = searchQuery.toLowerCase()
        return commands.filter(function(c) { return c.toLowerCase().includes(q) })
    }

    signal commandSelected(string command)

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (historyPopup.isClosing) {
                historyPopup.visible = false
                historyPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ historyPopup ]
        onCleared: historyPopup.forceClose()
    }

    Process {
        id: historyProc
        command: root.newUtill(["--getcommandhistory"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (!text || text === "none") {
                    historyPopup.commands = []
                    return
                }
                historyPopup.commands = text.split("\n").filter(function(c) { return c.trim() !== "" })
            }
        }
    }

    Rectangle {
        id: background
        width: panelWidth
        height: panelHeight
        radius: 15
        color: root.theme.background
        border.width: Theme.borderWidth
        border.color: Theme.border
        opacity: 0
        clip: true

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
            anchors.margins: 12
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Command History"
                    color: root.theme.text
                    font.family: root.settings.fontFamily
                    font.weight: 700
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }
                IconButton {
                    iconName: "close"
                    iconSize: 16
                    color: root.theme.text
                    tooltipText: "Close"
                    onClicked: historyPopup.forceClose()
                }
            }

            // Search
            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 8
                color: root.theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Image {
                        source: root.iconSource("search")
                        width: 16; height: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.5
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search commands..."
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 13
                        background: Item {}
                        onTextChanged: historyPopup.searchQuery = text
                    }
                }
            }

            // Empty state
            Text {
                visible: historyPopup.filteredCommands.length === 0
                text: historyPopup.commands.length === 0
                    ? "No history found"
                    : "No matches"
                color: root.theme.text
                opacity: 0.4
                font.family: root.settings.fontFamily
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
            }

            // Command list
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                contentHeight: cmdColumn.implicitHeight
                clip: true

                ColumnLayout {
                    id: cmdColumn
                    width: panelWidth - 24
                    spacing: 2

                    Repeater {
                        model: historyPopup.filteredCommands
                        delegate: RoundButton {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            padding: 6
                            horizontalPadding: 10

                            contentItem: RowLayout {
                                spacing: 8
                                Image {
                                    source: root.iconSource("terminal")
                                    width: 16; height: 16
                                    sourceSize.width: 16; sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                    opacity: 0.5
                                }
                                Text {
                                    text: modelData
                                    color: root.theme.text
                                    font.family: root.settings.fontFamily
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            background: Rectangle {
                                radius: 6
                                color: cmdHov.hovered ? root.theme.primary : "transparent"
                                opacity: cmdHov.hovered ? 0.18 : 1
                            }
                            HoverHandler { id: cmdHov; cursorShape: Qt.PointingHandCursor }
                            onClicked: {
                                historyPopup.commandSelected(modelData)
                                historyPopup.forceClose()
                            }
                        }
                    }
                }
            }
        }
    }

    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        historyPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) { alphaAnim.stop(); isClosing = false }
        updatePosition(widget)
        background.opacity = 0
        historyPopup.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        searchField.text = ""
        historyPopup.searchQuery = ""
        if (!historyProc.running) historyProc.running = true
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
        if (!historyPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}