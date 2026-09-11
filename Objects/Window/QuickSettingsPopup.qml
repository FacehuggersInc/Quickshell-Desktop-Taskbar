import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Hyprland

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

PopupWindow {
    id: quickPanel

    anchor.window: mainWindow
    anchor.rect.y: mainWindow.popupOffset(implicitHeight)
    implicitWidth: 400
    implicitHeight: Math.min(760, content.implicitHeight + 28)
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property Region glassBlurRegion: Region { item: background }
    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? glassBlurRegion : null

    property bool isClosing: false

    // ## Summaries
    // Read from the same systems the panels use, so nothing is polled twice

    readonly property string audioSummary: {
        var level = root.volumeWidget
            ? (root.volumeWidget.volumeMuted ? "Muted"
                                             : root.volumeWidget.volumeLevel + "%")
            : ""
        var device = root.audioPopup ? root.audioPopup.outputLabel : ""

        if (level === "" && device === "")
            return "Unavailable"
        if (device === "")
            return level
        if (level === "")
            return device
        return level + "  ·  " + device
    }

    readonly property string networkSummary: {
        if (!root.networkPopup)
            return "Unavailable"
        var vpn = root.networkPopup.netVpn
        if (vpn && vpn !== "no" && vpn !== "")
            return "VPN: " + vpn
        var name = root.networkPopup.netInterface
        return name && name !== "" ? name : "Disconnected"
    }

    // Read directly while the panel is open. Depending on a reference published
    // by another widget meant one missing assignment showed as "Unavailable".
    property bool btPowered: false
    property int btConnected: 0
    property string btDevice: ""
    property bool btRead: false

    Process {
        id: btStateProc
        command: root.newUtill(["--btstate"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                quickPanel.btRead = true
                if (!text)
                    return
                var obj = ({})
                text.split(",").forEach(function(pair) {
                    var kv = pair.split(":")
                    if (kv.length >= 2) obj[kv[0]] = kv.slice(1).join(":")
                })
                quickPanel.btPowered = obj["powered"] === "yes"
                quickPanel.btConnected = parseInt(obj["connected"] || "0")
                quickPanel.btDevice = obj["device"] || ""
            }
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: quickPanel.visible
        triggeredOnStart: true
        onTriggered: {
            if (!btStateProc.running) btStateProc.running = true
        }
    }

    readonly property string bluetoothSummary: {
        if (!quickPanel.btRead)
            return "Checking…"
        if (!quickPanel.btPowered)
            return "Adapter off"
        if (quickPanel.btConnected === 0)
            return "On, nothing connected"
        if (quickPanel.btDevice !== "")
            return quickPanel.btConnected > 1
                ? quickPanel.btDevice + " +" + (quickPanel.btConnected - 1)
                : quickPanel.btDevice
        return quickPanel.btConnected + " connected"
    }

    // ## USB
    // Only polled while open

    property var usbDrives: []

    Process {
        id: usbDetectProc
        command: ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINT,HOTPLUG,TYPE"]
        stdout: StdioCollector {
            onStreamFinished: {
                var drives = []
                try {
                    var data = JSON.parse(this.text)
                    var walk = function(nodes) {
                        for (var i = 0; i < nodes.length; i++) {
                            var n = nodes[i]
                            if (n.hotplug && n.mountpoint && n.type === "part") {
                                drives.push({
                                    label: n.label || n.name,
                                    mountpoint: n.mountpoint
                                })
                            }
                            if (n.children) walk(n.children)
                        }
                    }
                    walk(data.blockdevices || [])
                } catch (e) {}
                quickPanel.usbDrives = drives
            }
        }
    }

    Timer {
        id: usbTimer
        interval: 4000
        repeat: true
        running: quickPanel.visible
        triggeredOnStart: true
        onTriggered: {
            if (!usbDetectProc.running) usbDetectProc.running = true
        }
    }

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: Theme.durFast
        onFinished: {
            if (quickPanel.isClosing) {
                quickPanel.visible = false
                quickPanel.isClosing = false
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ quickPanel ]
        onCleared: quickPanel.forceClose()
    }

    function forceOpen(widget) {
        var position = mainWindow.itemPosition(widget)
        quickPanel.anchor.rect.x =
            (position.x + (widget.width / 2)) - (quickPanel.width / 2)

        quickPanel.isClosing = false
        background.opacity = 0
        quickPanel.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        BrightnessSystem.read()
    }

    function forceClose() {
        if (quickPanel.isClosing || !quickPanel.visible)
            return
        quickPanel.isClosing = true
        focusGrab.active = false
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
    }

    function toggle(widget) {
        if (!quickPanel.visible || quickPanel.isClosing) forceOpen(widget)
        else forceClose()
    }

    Rectangle {
        id: background
        width: quickPanel.implicitWidth
        height: quickPanel.implicitHeight
        radius: Theme.radius
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.border
        opacity: 0
        clip: true

        ColumnLayout {
            id: content
            x: 14
            y: 14
            width: background.width - 28
            spacing: Theme.gap

            // ## Brightness

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap

                Icon {
                    iconName: BrightnessSystem.value > 60 ? "backlight_high"
                        : BrightnessSystem.value > 20 ? "backlight_low"
                                                      : "backlight_off"
                    iconSize: 20
                    color: Theme.accentIcon
                }

                CustomSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    stepSize: 1
                    enabled: BrightnessSystem.available
                    opacity: enabled ? 1.0 : 0.4
                    onMoved: BrightnessSystem.set(this.value)

                    Binding {
                        target: brightnessSlider
                        property: "value"
                        value: BrightnessSystem.value
                        when: !brightnessSlider.pressed
                    }
                }

                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: BrightnessSystem.available
                        ? BrightnessSystem.value + "%" : "--"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.valueSize
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 30
                    Layout.leftMargin: 4
                    radius: Theme.radiusSmall
                    color: powerArea.containsMouse ? Theme.alpha(Theme.danger, 0.22)
                                                   : Theme.alpha(Theme.textBase, 0.09)
                    border.width: Theme.borderWidth
                    border.color: Theme.border

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Icon {
                        anchors.centerIn: parent
                        iconName: "lock"
                        iconSize: 16
                        color: powerArea.containsMouse ? Theme.danger : Theme.textDim
                    }

                    Tooltip {
                        id: powerTip
                        text: "Session"
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) powerTip.showAt(point)
                            else powerTip.hide()
                        }
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickPanel.forceClose()
                            quickPanel.openPower()
                        }
                    }
                }
            }

            // ## Wallpaper

            SettingRow {
                Layout.fillWidth: true
                iconName: "wallpaper"
                label: "Wallpaper"

                SegmentedControl {
                    options: [
                        { label: "Day", value: 1, color: "#f5a623" },
                        { label: "Auto", value: 0 },
                        { label: "Night", value: 2 }
                    ]
                    value: root.wallpaperMode
                    onPicked: (value) => {
                        root.wallpaperMode = value
                        root.settings.wallpapers.wallpaperMode = value
                        root.saveSettings()
                        root.nextWallpaper()
                    }
                }
            }

            // ## Tiles

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.gap
                rowSpacing: Theme.gap

                QuickTile {
                    Layout.fillWidth: true
                    iconName: "dark_mode"
                    label: "Theater"
                    sublabel: active ? "Dimming others" : "Off"
                    active: root.theaterMode
                    onActivated: root.setTheaterMode(!root.theaterMode)
                }

                QuickTile {
                    Layout.fillWidth: true
                    iconName: "hide"
                    label: "Gaming"
                    sublabel: active ? "Bar hidden" : "Off"
                    active: root.settings.gaming ? root.settings.gaming.enabled : false
                    onActivated: {
                        root.settings.gaming.enabled = !root.settings.gaming.enabled
                        root.saveSettings()
                    }
                }

                QuickTile {
                    Layout.fillWidth: true
                    iconName: "refresh"
                    label: "Next Wallpaper"
                    sublabel: "Cycle now"
                    enabled: root.settings.wallpapers.cycling !== false
                    onActivated: root.nextWallpaper()
                }

                QuickTile {
                    Layout.fillWidth: true
                    iconName: "apps"
                    label: "Workspaces"
                    sublabel: "Overview"
                    onActivated: {
                        quickPanel.forceClose()
                        root.overview.open()
                    }
                }
            }

            // ## Devices
            // A line of live state each, and a shortcut into the real panel —
            // the quick panel should answer "what is it doing" without a detour.

            SectionLabel { Layout.fillWidth: true; text: "Devices" }

            Repeater {
                model: [
                    {
                        key: "audio", icon: "media_output", label: "Audio",
                        target: root.audioPopup
                    },
                    {
                        key: "network", icon: "wired", label: "Network",
                        target: root.networkPopup
                    },
                    {
                        key: "bluetooth", icon: "bluetooth", label: "Bluetooth",
                        target: root.bluetoothPopup
                    }
                ]

                delegate: Rectangle {
                    required property var modelData

                    readonly property string detail: {
                        if (modelData.key === "audio")
                            return quickPanel.audioSummary
                        if (modelData.key === "network")
                            return quickPanel.networkSummary
                        return quickPanel.bluetoothSummary
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: Theme.radiusSmall
                    color: deviceArea.containsMouse ? Theme.alpha(Theme.accent, 0.18)
                                                    : Theme.alpha(Theme.textBase, 0.08)
                    border.width: Theme.borderWidth
                    border.color: Theme.border

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Icon {
                        id: deviceIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: modelData.icon
                        iconSize: 18
                        color: Theme.accentIcon
                    }

                    Column {
                        anchors.left: deviceIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSize
                            font.weight: 600
                        }

                        Text {
                            width: parent.width
                            text: parent.parent.detail
                            elide: Text.ElideRight
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }
                    }

                    MouseArea {
                        id: deviceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!modelData.target)
                                return
                            quickPanel.forceClose()
                            modelData.target.backTarget = quickPanel
                            modelData.target.forceOpen(mainWindow.settingsAnchor)
                        }
                    }
                }
            }

            // ## Quick access

            SectionLabel { Layout.fillWidth: true; text: "Quick Access" }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap

                Repeater {
                    model: [
                        { icon: "terminal", key: "terminal", tip: "Terminal" },
                        { icon: "open_folder", key: "files", tip: "Files" },
                        { icon: "screenshot", key: "screenshot", tip: "Screenshot" },
                        { icon: "filter", key: "colorpicker", tip: "Colour Picker" },
                        { icon: "settings", key: "config_quickshell", tip: "Shell Config" },
                        { icon: "restart", key: "restart_shell", tip: "Restart Shell" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Theme.radiusSmall
                        color: quickArea.containsMouse ? Theme.alpha(Theme.accent, 0.20)
                                                       : Theme.alpha(Theme.textBase, 0.09)
                        border.width: Theme.borderWidth
                        border.color: Theme.border

                        Icon {
                            anchors.centerIn: parent
                            iconName: modelData.icon
                            iconSize: 18
                            color: Theme.accentIcon
                        }

                        Tooltip {
                            id: quickTip
                            text: modelData.tip
                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered) quickTip.showAt(point)
                                else quickTip.hide()
                            }
                        }

                        MouseArea {
                            id: quickArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.cmdExec(modelData.key)
                                quickPanel.forceClose()
                            }
                        }
                    }
                }
            }

            // ## USB

            SectionLabel {
                Layout.fillWidth: true
                text: "Drives"
                visible: quickPanel.usbDrives.length > 0
            }

            Repeater {
                model: quickPanel.usbDrives

                delegate: SettingRow {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: "download"
                    label: modelData.label
                    description: modelData.mountpoint

                    Rectangle {
                        width: 68
                        height: Theme.controlHeight
                        radius: Theme.radiusSmall
                        color: openArea.containsMouse ? Theme.alpha(Theme.accent, 0.20)
                                                      : Theme.alpha(Theme.textBase, 0.10)
                        border.width: Theme.borderWidth
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "Open"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.valueSize
                        }

                        MouseArea {
                            id: openArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.cmdExec("files_open", { "path": modelData.mountpoint })
                                quickPanel.forceClose()
                            }
                        }
                    }
                }
            }

            // ## Footer

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Theme.radiusSmall
                color: allArea.containsMouse ? Theme.alpha(Theme.accent, 0.22)
                                             : Theme.alpha(Theme.textBase, 0.09)
                border.width: Theme.borderWidth
                border.color: Theme.border

                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                Text {
                    anchors.centerIn: parent
                    text: "All Settings"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.valueSize
                    font.weight: 600
                }

                MouseArea {
                    id: allArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        quickPanel.forceClose()
                        quickPanel.openFullSettings()
                    }
                }
            }
        }
    }

    signal openPower()
    signal openFullSettings()
}
