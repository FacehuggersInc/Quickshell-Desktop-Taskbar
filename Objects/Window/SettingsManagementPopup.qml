import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland

import qs.Objects.Design
import Qt5Compat.GraphicalEffects
import qs.Objects.Window
import qs.Objects.Widgets
import qs.Objects.Widgets.Internal

PopupWindow {
    id: generalSettingsPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth: 460
    property int panelHeight: Math.min(Screen.height - mainWindow.height - 20, 740)

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property bool isClosing: false

    // ── Brightness (ddcutil) ─────────────────────────────────────
    property var displayNames: []        // populated from ddcdetect on open
    property var brightnessValues: []    // one entry per detected display
    property bool brightnessBeingDragged: false  // prevents poll overwriting mid-drag

    // Global brightness debounce — sets all displays at once
    Timer {
        id: globalBrightnessDebounce
        interval: 350
        repeat: false
        property int pendingValue: 50
        onTriggered: {
            // Fire one ddcsetbrightness per display in parallel via separate procs
            for (var i = 0; i < generalSettingsPopup.brightnessValues.length; i++) {
                root.execute(root.newUtill(["--ddcsetbrightness", i + 1, pendingValue]))
            }
        }
    }

    // Per-display debounce — ddcutil is slow (~0.5s/display), don't call on every tick
    Timer {
        id: brightnessDebounce
        interval: 350
        repeat: false
        property int pendingDisplay: 1
        property int pendingValue: 50
        onTriggered: {
            root.execute(root.newUtill(["--ddcsetbrightness", pendingDisplay, pendingValue]))
        }
    }

    Process {
        id: detectProc
        command: root.newUtill(["--ddcdetect"])
        stdout: StdioCollector {
            onStreamFinished: {
                // Format: 1:ModelName|2:ModelName|3:ModelName
                var parts = this.text.trim().split("|")
                var names = []
                for (var i = 0; i < parts.length; i++) {
                    var kv = parts[i].split(":")
                    if (kv.length >= 2) names.push(kv.slice(1).join(":").trim())
                }
                generalSettingsPopup.displayNames = names
            }
        }
    }

    Process {
        id: brightnessGetProc
        command: root.newUtill(["--ddcgetbrightness"])
        stdout: StdioCollector {
            onStreamFinished: {
                // Format: 1:75:100|2:50:100|3:80:100
                var displays = this.text.trim().split("|")
                var vals = []
                for (var i = 0; i < displays.length; i++) {
                    var parts = displays[i].split(":")
                    if (parts.length < 3) { vals.push(50); continue }
                    var current = parseInt(parts[1])
                    var max     = parseInt(parts[2])
                    vals.push(max > 0 ? Math.round((current / max) * 100) : 50)
                }
                // Don't overwrite while user is dragging a slider
                if (!generalSettingsPopup.brightnessBeingDragged)
                    generalSettingsPopup.brightnessValues = vals
            }
        }
    }

    // ── Color Picker ─────────────────────────────────────────────────────────
    Process {
        id: colorPickerProc
        command: root.cmd("colorpicker")
        stdout: StdioCollector {
            onStreamFinished: {
                var color = this.text.trim()
                if (!color.match(/^#[0-9a-fA-F]{6}$/i)) return
                Quickshell.clipboardText = color
                addColorFromSettingsProc.command = root.newUtill(["--addcolor", color])
                addColorFromSettingsProc.running = true
            }
        }
    }

    Process {
        id: addColorFromSettingsProc
        stdout: StdioCollector {
            onStreamFinished: {
                var list = this.text.trim().split(",").filter(function(c) { return c !== "" })
                root.settings.colorHistory = list
                root.saveSettings()
            }
        }
    }

    function fetchBrightness() {
        if (!settingsOpenBatchProc.running) settingsOpenBatchProc.running = true
    }

    function setBrightness(displayNum, value) {
        // Update local state immediately for responsive UI
        var newVals = brightnessValues.slice()
        newVals[displayNum - 1] = value
        brightnessValues = newVals
        // Debounce the actual ddcutil call
        brightnessDebounce.pendingDisplay = displayNum
        brightnessDebounce.pendingValue   = value
        brightnessDebounce.restart()
    }


    // ── USB Drives ───────────────────────────────────────────────
    property var usbDrives: []   // [{label, mountpoint}]

    Process {
        id: usbDetectProc
        command: ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINT,HOTPLUG,TYPE"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    var drives = []
                    var devices = data["blockdevices"] || []
                    for (var i = 0; i < devices.length; i++) {
                        var dev = devices[i]
                        // hotplug can be true, "1", or 1 depending on lsblk version
                        var isHotplug = dev.hotplug === true
                            || dev.hotplug === "1"
                            || dev.hotplug === 1
                        if (!isHotplug) continue
                        var check = [dev].concat(dev.children || [])
                        for (var j = 0; j < check.length; j++) {
                            var part = check[j]
                            if (part.mountpoint && part.mountpoint !== ""
                                    && part.mountpoint !== null) {
                                drives.push({
                                    label: part.label && part.label !== ""
                                        ? part.label
                                        : part.name || "USB Drive",
                                    mountpoint: part.mountpoint
                                })
                            }
                        }
                    }
                    generalSettingsPopup.usbDrives = drives
                } catch(e) {
                    console.log("USB detect error: " + e)
                    generalSettingsPopup.usbDrives = []
                }
            }
        }
    }

    // Refresh USB list every 3s while popup is open
    Timer {
        id: usbRefreshTimer
        interval: 3000
        repeat: true
        running: false
        onTriggered: fetchUSB()
    }

    function fetchUSB() {
        if (!usbDetectProc.running) usbDetectProc.running = true
    }

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (generalSettingsPopup.isClosing) {
                generalSettingsPopup.visible = false
                generalSettingsPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ generalSettingsPopup ]
        onCleared: {
            // Immediately hide — don't wait for animation
            // Focus loss from launching an app (USB button, terminal etc.)
            // should close the panel instantly
            alphaAnim.stop()
            generalSettingsPopup.visible = false
            generalSettingsPopup.isClosing = false
            background.opacity = 0
            usbRefreshTimer.stop()
        }
    }

    // Batch proc for settings open — ddcdetect + ddcgetbrightness in one call
    Process {
        id: settingsOpenBatchProc
        command: root.newBatch([["ddcdetect"], ["ddcgetbrightness"]])
        stdout: StdioCollector {
            onStreamFinished: {
                var results = root.parseBatch(this.text)

                // ddcdetect
                if (results["ddcdetect"]) {
                    var parts = results["ddcdetect"].split("|")
                    var names = []
                    for (var i = 0; i < parts.length; i++) {
                        var kv = parts[i].split(":")
                        if (kv.length >= 2) names.push(kv.slice(1).join(":").trim())
                    }
                    generalSettingsPopup.displayNames = names
                }

                // ddcgetbrightness
                if (results["ddcgetbrightness"]) {
                    var displays = results["ddcgetbrightness"].split("|")
                    var vals = []
                    for (var j = 0; j < displays.length; j++) {
                        var dp = displays[j].split(":")
                        if (dp.length < 3) { vals.push(50); continue }
                        var cur = parseInt(dp[1])
                        var max = parseInt(dp[2])
                        vals.push(max > 0 ? Math.round((cur / max) * 100) : 50)
                    }
                    if (!generalSettingsPopup.brightnessBeingDragged)
                        generalSettingsPopup.brightnessValues = vals
                }
            }
        }
    }

    // ── Reusable full-width action row ────────────────────────────
    component ActionRow: RoundButton {
        property string iconName: "settings"
        property string label: ""
        property string description: ""

        Layout.fillWidth: true
        padding: 0
        horizontalPadding: 8
        implicitHeight: 42

        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            radius: 8
            color: hov.hovered ? root.settings.theme.primary : "transparent"
            opacity: hov.hovered ? 0.18 : 1
        }

        contentItem: RowLayout {
            spacing: 10

            IconButton {
                iconName: parent.parent.iconName
                iconSize: 20
                color: root.settings.theme.primary
                tooltipText: ""
                MouseArea {
                    anchors.fill: parent
                    onClicked: parent.parent.parent.clicked()
                }
            }

            Text {
                text: parent.parent.label
                color: root.settings.theme.text
                font.family: root.settings.fontFamily
                font.weight: 500
                font.pixelSize: 14
                Layout.fillWidth: true
            }

            Text {
                text: parent.parent.description
                color: root.settings.theme.text
                opacity: 0.45
                font.family: root.settings.fontFamily
                font.pixelSize: 12
                visible: text !== ""
            }
        }
    }

    // ── Background block ──────────────────────────────────────────
    Rectangle {
        id: background
        width: panelWidth
        height: panelHeight
        radius: 15
        color: root.settings.theme.background
        opacity: 0
        clip: true

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

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 12
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            contentWidth: panelWidth - 24
            contentHeight: settingsColumn.implicitHeight

            ColumnLayout {
                id: settingsColumn
                width: panelWidth - 24
                spacing: 2

                // ── WALLPAPER ─────────────────────────────────────
                TextDivider {
                    dividerText: "Wallpaper"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }

                // Cycling OFF — show stub instead of all wallpaper settings
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.settings.wallpapers.cycling === false
                    // NOTE: visible when cycling is explicitly false

                    Text {
                        text: "Wallpaper cycling is disabled."
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.pixelSize: 13
                        font.weight: 600
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: "All wallpaper settings are tied to the cycling system. To access interval, mode, and dark hour controls, enable cycling and configure your wallpaper folders in config.json."
                        color: root.settings.theme.text
                        opacity: 0.55
                        font.family: root.settings.fontFamily
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    RoundButton {
                        Layout.fillWidth: true
                        text: "Enable Wallpaper Cycling"
                        font.family: root.settings.fontFamily
                        font.pixelSize: 13
                        font.weight: 600
                        padding: 8
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: root.settings.theme.text
                            horizontalAlignment: Text.AlignHCenter
                        }
                        background: Rectangle {
                            radius: 8
                            color: root.settings.theme.primary
                            opacity: 0.7
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        onClicked: {
                            root.settings.wallpapers.cycling = true
                            root.saveSettings()
                        }
                    }
                }

                // Cycling ON — show full wallpaper settings
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    visible: root.settings.wallpapers.cycling !== false

                // Wallpaper interval
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "wallpaper"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: 0.7
                        tooltipText: "Wallpaper change interval"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Wallpaper Interval"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                        }

                        Text {
                            text: "e.g. 30s · 5m · 1h 30m · 2h · 90000ms"
                            color: root.settings.theme.text
                            opacity: 0.35
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // Editable field — accepts readable (30s, 5m, 1h 30m) or raw ms
                    Rectangle {
                        width: 150
                        height: 36
                        radius: 6
                        color: root.settings.theme.surface

                        // Border flashes red on bad input
                        border.color: intervalField.hasError
                            ? "#e05555"
                            : intervalField.activeFocus
                                ? root.settings.theme.primary
                                : "transparent"
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        TextField {
                            id: intervalField
                            anchors.fill: parent
                            anchors.margins: 6
                            font.family: root.settings.fontFamily
                            font.pixelSize: 13
                            color: root.settings.theme.text
                            background: Item {}
                            horizontalAlignment: Text.AlignHCenter
                            selectByMouse: true

                            property bool hasError: false
                            property bool userEditing: false

                            // Convert ms to readable on load / when not editing
                            function msToReadable(ms) {
                                var secs = Math.round(ms / 1000)
                                if (secs < 60) return secs + "s"
                                var m = Math.floor(secs / 60)
                                var s = secs % 60
                                if (m < 60) return s > 0 ? m + "m " + s + "s" : m + "m"
                                var h = Math.floor(m / 60)
                                var rem = m % 60
                                return rem > 0 ? h + "h " + rem + "m" : h + "h"
                            }

                            // Parse readable or raw ms → milliseconds
                            // Returns -1 on invalid input
                            function parseToMs(input) {
                                input = input.trim().toLowerCase()
                                if (!input) return -1

                                // Raw ms number
                                if (/^\d+ms$/.test(input)) return parseInt(input)
                                if (/^\d+$/.test(input))   return parseInt(input)  // bare number = ms

                                // Compound: 1h 30m 10s (any combination)
                                var total = 0
                                var matched = false
                                var hoursMatch  = input.match(/(\d+(?:\.\d+)?)\s*h/)
                                var minsMatch   = input.match(/(\d+(?:\.\d+)?)\s*m(?!s)/)
                                var secsMatch   = input.match(/(\d+(?:\.\d+)?)\s*s/)
                                if (hoursMatch) { total += parseFloat(hoursMatch[1])  * 3600000; matched = true }
                                if (minsMatch)  { total += parseFloat(minsMatch[1])   * 60000;   matched = true }
                                if (secsMatch)  { total += parseFloat(secsMatch[1])   * 1000;    matched = true }
                                if (matched && total > 0) return Math.round(total)

                                return -1
                            }

                            Component.onCompleted: {
                                text = msToReadable(root.settings.wallpapers.interval || 300000)
                            }

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    userEditing = true
                                } else {
                                    // Commit on focus loss
                                    commitValue()
                                }
                            }

                            onAccepted: commitValue()

                            function commitValue() {
                                var ms = parseToMs(text)
                                var maxMs = 43200000  // 12 hours
                                var minMs = 5000      // 5 seconds

                                if (ms < 0 || ms < minMs || ms > maxMs) {
                                    hasError = true
                                    errorResetTimer.restart()
                                    // Restore current value
                                    text = msToReadable(root.settings.wallpapers.interval || 300000)
                                    return
                                }

                                hasError = false
                                // setWallpaperInterval saves AND updates the live timer
                                root.setWallpaperInterval(ms)
                                // Reformat to canonical readable form
                                text = msToReadable(ms)
                                userEditing = false
                            }

                            Timer {
                                id: errorResetTimer
                                interval: 1500
                                onTriggered: intervalField.hasError = false
                            }
                        }
                    }
                }

                // Smart crop for vertical monitors
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "wallpaper"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: (root.settings.wallpapers.smartCrop || false) ? 1.0 : 0.45
                        tooltipText: "Smart crop for vertical monitors"
                        onClicked: {
                            root.settings.wallpapers.smartCrop = !(root.settings.wallpapers.smartCrop || false)
                            root.saveSettings()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Smart Crop (Vertical Monitors)"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (root.settings.wallpapers.smartCrop || false)
                                ? "Cropping to subject center on portrait displays"
                                : "Using wallpapers as-is on all displays"
                            color: root.settings.theme.text
                            opacity: 0.45
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: (root.settings.wallpapers.smartCrop || false)
                            ? root.settings.theme.primary
                            : Qt.rgba(1, 1, 1, 0.15)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: root.settings.theme.text
                            anchors.verticalCenter: parent.verticalCenter
                            x: (root.settings.wallpapers.smartCrop || false)
                                ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.settings.wallpapers.smartCrop = !(root.settings.wallpapers.smartCrop || false)
                                root.saveSettings()
                            }
                        }
                    }
                }

                // Wallpaper mode — sliding track, direct pick
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: root.wallpaperMode === 1 ? "light_mode"
                            : root.wallpaperMode === 2 ? "dark_mode"
                            : "wallpaper"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: root.wallpaperMode === 0 ? 0.45 : 1.0
                        tooltipText: "Wallpaper Mode"
                    }

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: "Wallpaper Mode"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                        }
                        Text {
                            text: root.wallpaperMode === 1 ? "Always day wallpapers"
                                : root.wallpaperMode === 2 ? "Always night wallpapers"
                                : "Following dark hour schedule"
                            color: root.settings.theme.text
                            opacity: 0.45
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Sliding track with 3 clickable zones
                    Item {
                        width: 96
                        height: 24

                        // Track background
                        Rectangle {
                            id: modeTrack
                            anchors.fill: parent
                            radius: 12
                            color: root.wallpaperMode === 1
                                ? "#f5a623"
                                : root.wallpaperMode === 2
                                    ? root.settings.theme.primary
                                    : Qt.rgba(1, 1, 1, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Sliding thumb
                        Rectangle {
                            id: modeThumb
                            width: 28
                            height: 18
                            radius: 9
                            color: root.settings.theme.text
                            anchors.verticalCenter: parent.verticalCenter
                            // day=left(1), auto=center(0), night=right(2)
                            x: root.wallpaperMode === 1 ? 3
                             : root.wallpaperMode === 2 ? parent.width - width - 3
                             : (parent.width - width) / 2
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        }

                        // Three invisible click zones covering Day / Auto / Night
                        Row {
                            anchors.fill: parent

                            Repeater {
                                model: [
                                    { mode: 1, tip: "Day"   },
                                    { mode: 0, tip: "Auto"  },
                                    { mode: 2, tip: "Night" }
                                ]
                                delegate: Item {
                                    required property var modelData
                                    width:  modeTrack.width / 3
                                    height: modeTrack.height

                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.wallpaperMode = modelData.mode
                                            root.settings.wallpapers.wallpaperMode = modelData.mode
                                            root.saveSettings()
                                            root.nextWallpaper()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Dark mode hours
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "dark_mode"
                        iconSize: 20
                        color: root.settings.theme.primary
                        tooltipText: "Dark mode hours"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "Dark Mode Hours"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                        }

                        // "From" hour
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "From"
                                color: root.settings.theme.text
                                opacity: 0.55
                                font.family: root.settings.fontFamily
                                font.pixelSize: 12
                                Layout.preferredWidth: 36
                            }

                            CustomSlider {
                                id: darkHourAtSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 23
                                stepSize: 1
                                handleBorderWidth: 0

                                Binding {
                                    target: darkHourAtSlider
                                    property: "value"
                                    value: root.settings.wallpapers.darkModeHours.at || 20
                                    when: !darkHourAtSlider.pressed
                                }

                                onMoved: {
                                    root.settings.wallpapers.darkModeHours.at = Math.round(this.value)
                                    root.saveSettings()
                                }
                            }

                            Text {
                                text: {
                                    var h = Math.round(darkHourAtSlider.value)
                                    var suffix = h >= 12 ? "pm" : "am"
                                    var display = h > 12 ? h - 12 : (h === 0 ? 12 : h)
                                    return display + suffix
                                }
                                color: root.settings.theme.text
                                font.family: root.settings.fontFamily
                                font.pixelSize: 13
                                font.weight: 500
                                Layout.preferredWidth: 38
                            }
                        }

                        // "Until" hour
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Until"
                                color: root.settings.theme.text
                                opacity: 0.55
                                font.family: root.settings.fontFamily
                                font.pixelSize: 12
                                Layout.preferredWidth: 36
                            }

                            CustomSlider {
                                id: darkHourBeforeSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 23
                                stepSize: 1
                                handleBorderWidth: 0

                                Binding {
                                    target: darkHourBeforeSlider
                                    property: "value"
                                    value: root.settings.wallpapers.darkModeHours.before || 7
                                    when: !darkHourBeforeSlider.pressed
                                }

                                onMoved: {
                                    root.settings.wallpapers.darkModeHours.before = Math.round(this.value)
                                    root.saveSettings()
                                }
                            }

                            Text {
                                text: {
                                    var h = Math.round(darkHourBeforeSlider.value)
                                    var suffix = h >= 12 ? "pm" : "am"
                                    var display = h > 12 ? h - 12 : (h === 0 ? 12 : h)
                                    return display + suffix
                                }
                                color: root.settings.theme.text
                                font.family: root.settings.fontFamily
                                font.pixelSize: 13
                                font.weight: 500
                                Layout.preferredWidth: 38
                            }
                        }

                        // Preview of the schedule
                        Text {
                            text: {
                                var at = Math.round(darkHourAtSlider.value)
                                var before = Math.round(darkHourBeforeSlider.value)
                                var toStr = function(h) {
                                    var s = h >= 12 ? "pm" : "am"
                                    var d = h > 12 ? h - 12 : (h === 0 ? 12 : h)
                                    return d + s
                                }
                                return "Night wallpapers " + toStr(at) + " → " + toStr(before)
                            }
                            color: root.settings.theme.primary
                            opacity: 0.7
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                }  // end cycling-on ColumnLayout

                Item { implicitHeight: 8 }

                // ── DISPLAY ───────────────────────────────────────
                TextDivider {
                    dividerText: "Display"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }

                // Global brightness — controls all displays at once
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: generalSettingsPopup.brightnessValues.length > 0
                            ? (generalSettingsPopup.brightnessValues.reduce(function(a,b){return a+b},0)
                               / generalSettingsPopup.brightnessValues.length) > 60
                                ? "backlight_high"
                                : (generalSettingsPopup.brightnessValues.reduce(function(a,b){return a+b},0)
                                   / generalSettingsPopup.brightnessValues.length) > 20
                                    ? "backlight_low"
                                    : "backlight_off"
                            : "backlight_high"
                        iconSize: 20
                        color: root.settings.theme.primary
                        tooltipText: "All Displays"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "All Displays"
                            color: root.settings.theme.text
                            opacity: 0.55
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }

                        CustomSlider {
                            id: globalBrightnessSlider
                            Layout.fillWidth: true
                            from: 1
                            to: 100
                            handleBorderWidth: 0
                            onPressedChanged: generalSettingsPopup.brightnessBeingDragged = pressed

                            Binding {
                                target: globalBrightnessSlider
                                property: "value"
                                value: generalSettingsPopup.brightnessValues.length > 0
                                    ? Math.round(generalSettingsPopup.brightnessValues.reduce(
                                        function(a,b){return a+b}, 0)
                                        / generalSettingsPopup.brightnessValues.length)
                                    : 50
                                when: !globalBrightnessSlider.pressed
                            }
                            onMoved: {
                                var v = Math.round(this.value)
                                var newVals = []
                                for (var i = 0; i < generalSettingsPopup.brightnessValues.length; i++) {
                                    newVals.push(v)
                                }
                                generalSettingsPopup.brightnessValues = newVals
                                globalBrightnessDebounce.pendingValue = v
                                globalBrightnessDebounce.restart()
                            }
                        }
                    }

                    Text {
                        text: generalSettingsPopup.brightnessValues.length > 0
                            ? Math.round(generalSettingsPopup.brightnessValues.reduce(
                                function(a,b){return a+b},0)
                                / generalSettingsPopup.brightnessValues.length) + "%"
                            : "?%"
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 14
                        Layout.preferredWidth: 38
                    }
                }

                // Divider between global and per-display
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.settings.theme.text
                    opacity: 0.08
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                // Per-display brightness sliders
                Repeater {
                    model: generalSettingsPopup.displayNames.length
                    delegate: RowLayout {
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        IconButton {
                            iconName: {
                                var v = generalSettingsPopup.brightnessValues[index] || 50
                                if (v > 60) return "backlight_high"
                                if (v > 20) return "backlight_low"
                                return "backlight_off"
                            }
                            iconSize: 20
                            color: root.settings.theme.primary
                            tooltipText: generalSettingsPopup.displayNames[index] || ""
                        }

                        Text {
                            text: generalSettingsPopup.displayNames[index] || "Display " + (index + 1)
                            color: root.settings.theme.text
                            opacity: 0.55
                            font.family: root.settings.fontFamily
                            font.pixelSize: 12
                            Layout.preferredWidth: 115
                            elide: Text.ElideRight
                        }

                        CustomSlider {
                            Layout.fillWidth: true
                            from: 1
                            to: 100
                            handleBorderWidth: 0
                            id: perDisplaySlider
                            onPressedChanged: generalSettingsPopup.brightnessBeingDragged = pressed
                            onMoved: generalSettingsPopup.setBrightness(index + 1, Math.round(this.value))

                            Binding {
                                target: perDisplaySlider
                                property: "value"
                                value: generalSettingsPopup.brightnessValues[index] || 50
                                when: !perDisplaySlider.pressed
                            }
                        }

                        Text {
                            text: (generalSettingsPopup.brightnessValues[index] || 50) + "%"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                            Layout.preferredWidth: 38
                        }
                    }
                }


                // Primary monitor picker
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "show"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: 0.7
                        tooltipText: "Primary display"
                    }

                    Text {
                        text: "Primary Display"
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }

                    Row {
                        spacing: 4
                        Repeater {
                            model: root.settings.displays || []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                property bool isSelected: index === (root.settings.primaryDisplayIndex || 0)
                                width:  primaryLabel.implicitWidth + 16
                                height: 26
                                radius: 6
                                color: isSelected ? root.settings.theme.primary : root.settings.theme.surface
                                opacity: isSelected ? 0.9 : 0.5
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    id: primaryLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.settings.theme.text
                                    font.family: root.settings.fontFamily
                                    font.pixelSize: 11
                                    font.weight: isSelected ? 700 : 400
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.settings.primaryDisplayIndex = index
                                        root.saveSettings()
                                    }
                                }
                            }
                        }
                    }
                }

                // Refresh displays from Hyprland
                ActionRow {
                    iconName: "refresh"
                    label: "Refresh Displays"
                    description: "Re-detect from Hyprland"
                    onClicked: {
                        if (!startupBatchProc.running) startupBatchProc.running = true
                    }
                }

                Item { implicitHeight: 8 }

                // ── THEATER ───────────────────────────────────────
                TextDivider {
                    dividerText: "Theater"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }

                // Theater mode toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: root.theaterMode ? "hide" : "show"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: root.theaterMode ? 1.0 : 0.45
                        tooltipText: "Theater Mode"
                        onClicked: root.setTheaterMode(!root.theaterMode)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Theater Mode"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                        }
                        Text {
                            text: root.theaterMode
                                ? "Non-primary displays dimmed"
                                : "Dims non-primary displays to " + (root.settings.theater ? root.settings.theater.dimBrightness || 10 : 10) + "%"
                            color: root.settings.theme.text
                            opacity: 0.45
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: root.theaterMode ? root.settings.theme.primary : Qt.rgba(1,1,1,0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: root.settings.theme.text
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.theaterMode ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setTheaterMode(!root.theaterMode)
                        }
                    }
                }

                // Dim brightness slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "backlight_low"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: 0.7
                        tooltipText: "Dim brightness"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Dim Brightness"
                            color: root.settings.theme.text
                            opacity: 0.55
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                        CustomSlider {
                            id: theaterDimSlider
                            Layout.fillWidth: true
                            from: 0; to: 50; stepSize: 1
                            handleBorderWidth: 0
                            Binding {
                                target: theaterDimSlider
                                property: "value"
                                value: root.settings.theater ? root.settings.theater.dimBrightness || 10 : 10
                                when: !theaterDimSlider.pressed
                            }
                            onMoved: {
                                if (!root.settings.theater) root.settings.theater = {}
                                root.settings.theater.dimBrightness = Math.round(this.value)
                                root.saveSettings()
                            }
                        }
                    }

                    Text {
                        text: Math.round(theaterDimSlider.value) + "%"
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 13
                        Layout.preferredWidth: 38
                    }
                }

                // Theater wallpaper path
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "wallpaper"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: 0.7
                        tooltipText: "Theater wallpaper"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Theater Wallpaper"
                            color: root.settings.theme.text
                            opacity: 0.55
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 6
                            color: root.settings.theme.surface
                            border.color: theaterWallpaperField.activeFocus
                                ? root.settings.theme.primary : "transparent"
                            border.width: 1
                            TextField {
                                id: theaterWallpaperField
                                anchors.fill: parent
                                anchors.margins: 6
                                placeholderText: "/path/to/dark/wallpaper.jpg"
                                text: root.settings.theater ? root.settings.theater.wallpaper || "" : ""
                                color: root.settings.theme.text
                                font.family: root.settings.fontFamily
                                font.pixelSize: 12
                                background: Item {}
                                onAccepted: {
                                    if (!root.settings.theater) root.settings.theater = {}
                                    root.settings.theater.wallpaper = text.trim()
                                    root.saveSettings()
                                }
                                onActiveFocusChanged: {
                                    if (!activeFocus) {
                                        if (!root.settings.theater) root.settings.theater = {}
                                        root.settings.theater.wallpaper = text.trim()
                                        root.saveSettings()
                                    }
                                }
                            }
                        }
                    }
                }

                // Theater primary display picker
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "show"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: 0.7
                        tooltipText: "Primary display"
                    }

                    Text {
                        text: "Primary Display"
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }

                    Row {
                        spacing: 4
                        Repeater {
                            model: root.settings.displays || []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                property bool isSelected: {
                                    var t = root.settings.theater
                                    var p = t && t.primaryDisplay !== undefined && t.primaryDisplay !== null
                                        ? t.primaryDisplay
                                        : (root.settings.primaryDisplayIndex || 0)
                                    return index === p
                                }
                                width:  theaterDisplayLabel.implicitWidth + 16
                                height: 26
                                radius: 6
                                color: isSelected ? root.settings.theme.primary : root.settings.theme.surface
                                opacity: isSelected ? 0.9 : 0.5
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    id: theaterDisplayLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.settings.theme.text
                                    font.family: root.settings.fontFamily
                                    font.pixelSize: 11
                                    font.weight: isSelected ? 700 : 400
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (!root.settings.theater) root.settings.theater = {}
                                        root.settings.theater.primaryDisplay = index
                                        root.saveSettings()
                                    }
                                }
                            }
                        }
                    }
                }

                Item { implicitHeight: 8 }

                // ── QUICK ACCESS ──────────────────────────────────
                TextDivider {
                    dividerText: "Quick Access"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "wallpaper"
                    label: "Next Wallpaper"
                    onClicked: root.nextWallpaper()
                }
                ActionRow {
                    iconName: "open_folder"
                    label: "File Manager"
                    description: root.cmdDesc("files")
                    onClicked: root.execute(root.cmd("files"))
                }
                ActionRow {
                    iconName: "terminal"
                    label: "Terminal"
                    description: root.cmdDesc("terminal")
                    onClicked: root.execute(root.cmd("terminal"))
                }
                ActionRow {
                    iconName: "copy_content"
                    label: "Color Picker"
                    description: colorPickerProc.running
                        ? "picking..."
                        : root.cmdDesc("colorpicker")
                    onClicked: {
                        if (!colorPickerProc.running) colorPickerProc.running = true
                    }
                }
                ActionRow {
                    iconName: "screenshot"
                    label: "Screenshot"
                    description: root.cmdDesc("screenshot")
                    onClicked: root.execute(root.cmd("screenshot"))
                }

                // USB drives — only visible when drives are mounted
                Repeater {
                    model: generalSettingsPopup.usbDrives
                    delegate: ActionRow {
                        required property var modelData
                        iconName: "open_folder"
                        label: modelData.label
                        description: modelData.mountpoint
                        onClicked: root.execute(root.cmd("files_open", {"path": modelData.mountpoint}))
                    }
                }


                Item { implicitHeight: 8 }

                // ── CONFIGURATIONS ────────────────────────────────
                TextDivider {
                    dividerText: "Configurations"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "settings"
                    label: "Shell Config (config.json)"
                    description: root.cmdDesc("config_json")
                    onClicked: root.execute(root.cmd("config_json"))
                }
                ActionRow {
                    iconName: "settings"
                    label: "Hyprland Config"
                    description: root.cmdDesc("config_hypr")
                    onClicked: root.execute(root.cmd("config_hypr"))
                }
                ActionRow {
                    iconName: "settings"
                    label: "Quickshell Config"
                    description: root.cmdDesc("config_quickshell")
                    onClicked: root.execute(root.cmd("config_quickshell"))
                }
                ActionRow {
                    iconName: "open_folder"
                    label: "All Dotfiles"
                    description: root.cmdDesc("config_main")
                    onClicked: root.execute(root.cmd("config_main"))
                }
                ActionRow {
                    iconName: "refresh"
                    label: "Reload Hyprland Config"
                    description: root.cmdDesc("hypr_reload")
                    onClicked: root.execute(root.cmd("hypr_reload"))
                }

                Item { implicitHeight: 8 }

                // ── HYPRLAND ──────────────────────────────────────
                TextDivider {
                    dividerText: "Hyprland"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    id: animToggle
                    property bool on: true
                    iconName: "settings"
                    label: "Toggle Animations"
                    description: on ? "currently on" : "currently off"
                    onClicked: {
                        on = !on
                        root.execute(["hyprctl", "keyword", "animations:enabled", on ? "true" : "false"])
                    }
                }
                ActionRow {
                    id: blurToggle
                    property bool on: true
                    iconName: "settings"
                    label: "Toggle Blur"
                    description: on ? "currently on" : "currently off"
                    onClicked: {
                        on = !on
                        root.execute(["hyprctl", "keyword", "decoration:blur:enabled", on ? "true" : "false"])
                    }
                }


                Item { implicitHeight: 8 }

                // ── POWER ─────────────────────────────────────────
                TextDivider {
                    dividerText: "Power"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "lock"
                    label: "Lock Screen"
                    description: root.cmdDesc("logout")
                    onClicked: root.execute(root.cmd("logout"))
                }
                ActionRow {
                    iconName: "hide"
                    label: "Suspend"
                    description: root.cmdDesc("suspend")
                    onClicked: root.execute(root.cmd("suspend"))
                }
                ActionRow {
                    iconName: "restart"
                    label: "Reboot"
                    description: root.cmdDesc("reboot")
                    onClicked: root.execute(root.cmd("reboot"))
                }
                ActionRow {
                    iconName: "stop"
                    label: "Shutdown"
                    description: root.cmdDesc("poweroff")
                    onClicked: root.execute(root.cmd("poweroff"))
                }

                Item { implicitHeight: 8 }

                // ── DEBUG ─────────────────────────────────────────
                TextDivider {
                    dividerText: "Debug"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "restart"
                    label: "Restart Quickshell"
                    description: root.cmdDesc("restart_shell")
                    onClicked: root.execute(root.cmd("restart_shell"))
                }

                // bottom breathing room
                Item { implicitHeight: 8 }
            }
        }
    }

    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        generalSettingsPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) {
            alphaAnim.stop()
            isClosing = false
        }
        updatePosition(widget)
        background.opacity = 0
        generalSettingsPopup.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        fetchBrightness()
        fetchUSB()
        usbRefreshTimer.start()
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
        focusGrab.active = false
        usbRefreshTimer.stop()
    }

    function toggle(widget) {
        if (!generalSettingsPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}