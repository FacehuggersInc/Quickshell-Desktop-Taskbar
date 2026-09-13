import Quickshell
import Quickshell.Wayland

import qs.Objects.Theme
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Window
import qs.Objects.Widgets
import qs.Objects.Widgets.Internal

PopupWindow {
    id: volumeSettingsPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.popupOffset(implicitHeight)

    property int panelWidth: 500
    property int panelHeight: Math.min(Screen.height - mainWindow.height - 20, 480)

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property Region glassBlurRegion: Region { item: background }
    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? glassBlurRegion : null

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: volumeSettingsPopup.forceClose()
    }

    property bool isClosing: false

    // Previously reached through VolumeWidget by scope, which stopped working
    // when this popup moved out of it
    function getStyleFromPercentage(str) {
        var num = parseInt(str)
        if (num >= 60)
            return [Theme.danger, "volume_max", num]
        if (num >= 50)
            return [Theme.accentIcon, "volume_max", num]
        if (num >= 20)
            return [Theme.accentIcon, "volume_med", num]
        return [Theme.textDim, "volume_min", num]
    }

    // ## Back
    // Set when the quick panel opened this, so there is a way to return

    property var backTarget: null

    function goBack() {
        var target = volumeSettingsPopup.backTarget
        volumeSettingsPopup.backTarget = null
        volumeSettingsPopup.forceClose()
        if (target && mainWindow.settingsAnchor)
            target.forceOpen(mainWindow.settingsAnchor)
    }


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
                volumeSettingsPopup.buildDevices()
            }
        }
    }

    function setVolume(id, value) {
        root.execute(root.cmd("audio_set_volume", {"id": id, "value": value / 100}))
    }

    function setDevice(index, closeAfter) {
        root.execute(root.cmd("audio_set_default", {"index": index}))
        if (closeAfter) volumeSettingsPopup.forceClose()
        root.notify("Audio Management",
                    "Output: " + volumeSettingsPopup.outputLabel
                    + "\nInput: " + volumeSettingsPopup.inputLabel,
                    "media_output")
    }

    // ## Devices
    // Plain arrays feeding SelectBox, so the audio devices use the same control
    // as everything else instead of a bespoke combo box

    property var outputOptions: []
    property var inputOptions: []
    property int outputCurrent: -1
    property int inputCurrent: -1
    property string outputLabel: ""
    property string inputLabel: ""

    function parseDevices(items) {
        var options = []
        var current = -1
        var label = ""
        for (var i = 0; i < items.length; i++) {
            var parts = items[i].split(",")
            if (parts.length < 4) continue
            var id = parseInt(parts[0])
            options.push({ label: parts[3], value: id })
            if (parts[2].includes("True")) {
                current = id
                label = parts[3]
            }
        }
        return { options: options, current: current, label: label }
    }

    function buildDevices() {
        var out = parseDevices(getDevicesProc.outputs)
        volumeSettingsPopup.outputOptions = out.options
        volumeSettingsPopup.outputCurrent = out.current
        volumeSettingsPopup.outputLabel = out.label

        var inp = parseDevices(getDevicesProc.inputs)
        volumeSettingsPopup.inputOptions = inp.options
        volumeSettingsPopup.inputCurrent = inp.current
        volumeSettingsPopup.inputLabel = inp.label
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
            volumeSliderIcon.setColor(Theme.accentIcon)
            volumeSliderIcon.setIcon(style[1])
            volumeSliderText.text = style[2] + "%"
        } else {
            volumeSliderIcon.setColor(Theme.textMute)
            volumeSliderIcon.setIcon("volume_mute")
            volumeSliderText.text = "Mute"
        }

        if (micOn) {
            micSliderIcon.setIcon("microphone")
            micSliderIcon.setColor(Theme.ok)
            micSliderText.text = micPct + "%"
        } else {
            micSliderIcon.setColor(Theme.textMute)
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

        // Back to quick settings
        Rectangle {
            visible: volumeSettingsPopup.backTarget !== null
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
                onClicked: volumeSettingsPopup.goBack()
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

        // Eat clicks inside so they don't fall through to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.7
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
            blurMax: 24
        }

        // ── Scrollable content ────────────────────────────────────
        ScrollView {
            id: audioScroll
            anchors.fill: parent
            anchors.margins: 12
            // Pushed clear of the back control rather than sitting under it
            anchors.topMargin: volumeSettingsPopup.backTarget !== null ? 38 : 12
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            // availableWidth accounts for the scrollbar. The old fixed value
            // was the full panel width, so content ran under the bar and past
            // the edge whenever the list was long enough to scroll.
            contentWidth: availableWidth
            contentHeight: audioColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: audioColumn
                width: audioScroll.availableWidth
                spacing: Theme.gap

                // ── MEDIA ─────────────────────────────────────────
                SectionLabel {
                    id: mediaHeader
                    text: "Media"
                    Layout.fillWidth: true
                }

                CurrentlyPlayingInternal {
                    id: currentlyPlaying
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    textColor: root.theme.text
                    textWordWrap: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    spacing: Theme.gap

                    IconButton {
                        iconName: "music_prev"
                        iconSize: 24
                        tooltipText: "Previous"
                        color: root.theme.primary
                        radius: 8
                        borderColor: root.theme.primary
                        borderWidth: 2
                        Layout.preferredWidth: 95
                        Layout.preferredHeight: 40
                        onClicked: prevCommand.running = true
                        Process { id: prevCommand; command: root.cmd("media_previous") }
                    }
                    IconButton {
                        id: playPauseButton
                        iconName: "music_pause"
                        iconSize: 24
                        tooltipText: "Play/Pause"
                        color: root.theme.primary
                        radius: 8
                        borderColor: root.theme.primary
                        borderWidth: 2
                        Layout.preferredWidth: 95
                        Layout.preferredHeight: 40
                        onClicked: toggleCommand.running = true
                        Process { id: toggleCommand; command: root.cmd("media_toggle") }
                    }
                    IconButton {
                        iconName: "music_skip"
                        iconSize: 24
                        tooltipText: "Skip"
                        color: root.theme.primary
                        radius: 8
                        borderColor: root.theme.primary
                        borderWidth: 2
                        Layout.preferredWidth: 95
                        Layout.preferredHeight: 40
                        onClicked: nextCommand.running = true
                        Process { id: nextCommand; command: root.cmd("media_next") }
                    }
                }

                // ── VOLUME CONTROL ────────────────────────────────
                SectionLabel {
                    text: "Volume Control"
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    IconButton {
                        id: volumeSliderIcon
                        iconName: "volume_min"
                        iconSize: 20
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
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 16
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    IconButton {
                        id: micSliderIcon
                        iconName: "microphone_alert"
                        iconSize: 20
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
                        color: root.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 16
                    }
                }

                // ── AUDIO DEVICES ─────────────────────────────────
                SectionLabel {
                    Layout.fillWidth: true
                    text: "Audio Devices"
                }

                SettingRow {
                    Layout.fillWidth: true
                    iconName: "media_output"
                    label: "Output"
                    description: volumeSettingsPopup.outputLabel

                    SelectBox {
                        width: 260
                        options: volumeSettingsPopup.outputOptions
                        value: volumeSettingsPopup.outputCurrent
                        onPicked: (v) => volumeSettingsPopup.setDevice(v, false)
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    iconName: "media_input"
                    label: "Input"
                    description: volumeSettingsPopup.inputLabel

                    SelectBox {
                        width: 260
                        options: volumeSettingsPopup.inputOptions
                        value: volumeSettingsPopup.inputCurrent
                        onPicked: (v) => volumeSettingsPopup.setDevice(v, false)
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
        // Opened from the bar, so there is nothing to go back to
        volumeSettingsPopup.backTarget = null
        if (!volumeSettingsPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}