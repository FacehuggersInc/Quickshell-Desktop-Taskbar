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
import qs.Objects.Widgets.Internal

PopupWindow {
    id: volumeSettingsPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth: 500
    property int panelHeight: Math.min(Screen.height - mainWindow.height - 20, 480)

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: volumeSettingsPopup.forceClose()
    }

    property bool isClosing: false

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (volumeSettingsPopup.isClosing) {
                volumeSettingsPopup.visible = false
                volumeSettingsPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ volumeSettingsPopup ]
        onCleared: {
            alphaAnim.stop()
            volumeSettingsPopup.isClosing = false
            volumeSettingsPopup.visible = false
            background.opacity = 0
        currentlyPlayingUpdater.running = false
        currentlyPlayingUpdater.repeat = false
        }
    }

    Timer {
        id: currentlyPlayingUpdater
        interval: 300
        onTriggered: updateCurrentlyPlaying()
    }

    Process {
        id: getDevicesProc
        property var outputs: []
        property var inputs: []
        running: true
        command: root.newUtill(["--getaudiodevices"])
        stdout: StdioCollector {
            onStreamFinished: {
                getDevicesProc.outputs = []
                getDevicesProc.inputs = []
                var devices = this.text.split("|")
                for (var i = 0; i < devices.length; i++) {
                    var device = devices[i]
                    var parts = device.split(",")
                    if (parts[1].includes("output")) {
                        getDevicesProc.outputs.push(device)
                    } else if (parts[1].includes("input")) {
                        getDevicesProc.inputs.push(device)
                    }
                }
                fillDeviceComboBox(outputDevices, getDevicesProc.outputs)
                fillDeviceComboBox(inputDevices, getDevicesProc.inputs)
            }
        }
    }

    function setVolume(id, value) {
        root.execute(["wpctl", "set-volume", id, value / 100])
    }

    function setDevice(index, closeAfter) {
        root.execute(["wpctl", "set-default", index])
        if (closeAfter) volumeSettingsPopup.forceClose()
        root.notify("Audio Management", "Output: " + outputDevices.displayText + "\nInput: " + inputDevices.displayText, "media_output")
    }

    function fillDeviceComboBox(combo, items) {
        combo.items.clear()
        var defaultIndex = 0
        for (var i = 0; i < items.length; i++) {
            var parts = items[i].split(",")
            if (parts[2].includes("True")) {
                defaultIndex = i
                combo.selectedId = parseInt(parts[0])
            }
            combo.items.append({
                "id": parseInt(parts[0]),
                "name": parts[3],
                "index": i
            })
        }
        combo.currentIndex = defaultIndex
        combo.popup.height = items.length * 45
    }

    function updateCurrentlyPlaying() {
        if (root.media.status === "Playing" || root.media.status === "Paused") {
            var info = ""
            if (root.media.album)  info += root.media.album
            if (root.media.artist) info += info ? "\n" + root.media.artist : root.media.artist

            mediaHeader.setExtraText(root.media.source ? root.media.source : "Audio")
            currentlyPlaying.lastTitle = root.media.title.trim()
            currentlyPlaying.lastInfo  = info.trim()
            currentlyPlaying.setPlaying(root.media.title.trim())
            currentlyPlaying.setInfo(info.trim())
            playPauseButton.setIcon(root.media.status === "Playing" ? "music_pause" : "music_play")
        } else {
            currentlyPlaying.lastTitle = ''
            currentlyPlaying.lastInfo  = ''
            currentlyPlaying.setPlaying('')
            currentlyPlaying.setInfo('')
            currentlyPlaying.setControlsVisibleState(false)
            playPauseButton.setIcon("music_play")
        }
    }

    function updateSliderInfo(includeSlidersValues) {
        var state = volumeWidget.volumeState
        var volPct = parseInt(state[0].replace("%", ""))
        var volOn  = state[1].includes("on")
        var micPct = parseInt(state[2].replace("%", ""))
        var micOn  = state[3].includes("on")

        if (volOn) {
            var style = getStyleFromPercentage(volPct)
            volumeSliderIcon.setColor(root.settings.theme.primary)
            volumeSliderIcon.setIcon(style[1])
            volumeSliderText.text = style[2] + "%"
        } else {
            volumeSliderIcon.setColor('#848484')
            volumeSliderIcon.setIcon("volume_mute")
            volumeSliderText.text = "Mute"
        }

        if (micOn) {
            micSliderIcon.setIcon("microphone")
            micSliderIcon.setColor('#ff4a4a')
            micSliderText.text = micPct + "%"
        } else {
            micSliderIcon.setColor(root.settings.theme.primary)
            micSliderIcon.setIcon("microphone_mute")
            micSliderText.text = "Mute"
        }

        if (includeSlidersValues) {
            if (!volumeSlider.pressed) volumeSlider.value = volPct
            if (!micSlider.pressed)    micSlider.value    = micPct
        }
    }

    // ── Background ────────────────────────────────────────────────
    Rectangle {
        id: background
        width: panelWidth
        height: panelHeight
        radius: 15
        color: root.settings.theme.background
        opacity: 0
        clip: true

        // Eat clicks inside so they don't fall through to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 1
            verticalOffset: 1
            radius: 25
            samples: 100
            color: "#80000000"
            source: background
        }

        // ── Scrollable content ────────────────────────────────────
        ScrollView {
            anchors.fill: parent
            anchors.margins: 12
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            contentWidth: panelWidth - 24
            contentHeight: audioColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: audioColumn
                width: panelWidth - 24
                spacing: 10

                // ── MEDIA ─────────────────────────────────────────
                TextDivider {
                    id: mediaHeader
                    dividerText: "Media"
                    dividerHeight: 3
                    Layout.fillWidth: true
                }

                CurrentlyPlayingInternal {
                    id: currentlyPlaying
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    textColor: root.settings.theme.text
                    textWordWrap: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    spacing: 6

                    IconButton {
                        iconName: "music_prev"
                        iconSize: 50
                        tooltipText: "Previous"
                        color: root.settings.theme.primary
                        radius: 8
                        borderColor: root.settings.theme.primary
                        borderWidth: 2
                        Layout.preferredWidth: 95
                        Layout.preferredHeight: 40
                        onClicked: prevCommand.running = true
                        Process { id: prevCommand; command: ["playerctl", "previous"] }
                    }
                    IconButton {
                        id: playPauseButton
                        iconName: "music_pause"
                        iconSize: 50
                        tooltipText: "Play/Pause"
                        color: root.settings.theme.primary
                        radius: 8
                        borderColor: root.settings.theme.primary
                        borderWidth: 2
                        Layout.preferredWidth: 95
                        Layout.preferredHeight: 40
                        onClicked: toggleCommand.running = true
                        Process { id: toggleCommand; command: ["playerctl", "play-pause"] }
                    }
                    IconButton {
                        iconName: "music_skip"
                        iconSize: 50
                        tooltipText: "Skip"
                        color: root.settings.theme.primary
                        radius: 8
                        borderColor: root.settings.theme.primary
                        borderWidth: 2
                        Layout.preferredWidth: 95
                        Layout.preferredHeight: 40
                        onClicked: nextCommand.running = true
                        Process { id: nextCommand; command: ["playerctl", "next"] }
                    }
                }

                // ── VOLUME CONTROL ────────────────────────────────
                TextDivider {
                    dividerText: "Volume Control"
                    dividerHeight: 3
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    IconButton {
                        id: volumeSliderIcon
                        iconName: "volume_min"
                        iconSize: 45
                        tooltipText: ""
                    }
                    CustomSlider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        handleBorderWidth: 0
                        onMoved: setVolume(outputDevices.selectedId, this.value)
                    }
                    Text {
                        id: volumeSliderText
                        text: "0%"
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 16
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    IconButton {
                        id: micSliderIcon
                        iconName: "microphone_alert"
                        iconSize: 45
                        tooltipText: ""
                        onClicked: volumeWidget.toggleMicMute()
                    }
                    CustomSlider {
                        id: micSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        handleBorderWidth: 0
                        onMoved: setVolume(inputDevices.selectedId, this.value)
                    }
                    Text {
                        id: micSliderText
                        text: "0%"
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 16
                    }
                }

                // ── AUDIO DEVICES ─────────────────────────────────
                TextDivider {
                    dividerText: "Audio Devices"
                    dividerHeight: 3
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    IconButton {
                        iconName: "media_output"
                        iconSize: 45
                        tooltipText: "Output Device"
                        color: root.settings.theme.primary
                    }
                    DeviceComboBox {
                        id: outputDevices
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    IconButton {
                        iconName: "media_input"
                        iconSize: 45
                        tooltipText: "Input Device"
                        color: root.settings.theme.primary
                    }
                    DeviceComboBox {
                        id: inputDevices
                        Layout.fillWidth: true
                    }
                }

                Item { implicitHeight: 4 }
            }
        }
    }

    // ── Open / close API ─────────────────────────────────────────
    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        volumeSettingsPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) {
            alphaAnim.stop()
            isClosing = false
        }
        updatePosition(widget)
        background.opacity = 0
        volumeSettingsPopup.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        getDevicesProc.running = true
        currentlyPlayingUpdater.running = true
        currentlyPlayingUpdater.repeat = true
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
        focusGrab.active = false
        currentlyPlayingUpdater.running = false
        currentlyPlayingUpdater.repeat = false
    }

    function toggle(widget) {
        if (!volumeSettingsPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}