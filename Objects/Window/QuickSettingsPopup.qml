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
    implicitWidth: 1000
    implicitHeight: Math.min(760, content.implicitHeight + 28)
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property Region glassBlurRegion: Region { item: background }
    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? glassBlurRegion : null

    property bool isClosing: false
    property double lastBrightnessRead: 0

    // ## Session
    // Read from /proc and the environment rather than shelling out

    property string userName: Quickshell.env("USER")
        ? Quickshell.env("USER") : "user"
    property string hostName: ""
    property string uptime: "…"

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: quickPanel.uptime = quickPanel.formatUptime(this.text())
    }

    FileView {
        id: hostFile
        path: "/etc/hostname"
        preload: true
        onLoaded: quickPanel.hostName = this.text().trim()
    }

    function formatUptime(raw) {
        var seconds = parseFloat(String(raw).trim().split(" ")[0])
        if (!seconds || seconds <= 0)
            return "…"

        var days = Math.floor(seconds / 86400)
        var hours = Math.floor((seconds % 86400) / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)

        if (days > 0)
            return days + "d " + hours + "h"
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    Timer {
        interval: 60000
        repeat: true
        running: quickPanel.visible
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

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
        return level + " · " + device
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
            if (!micStateProc.running) micStateProc.running = true
        }
    }

    // Wired and VPN both explain an idle radio better than "off" does
    readonly property string wifiIcon: {
        var state = quickPanel.wifiLabel
        if (state === "Wired")
            return "wired"
        if (state === "VPN")
            return "vpn"
        return "wifi_max"
    }

    // What you are actually connected through, whatever the radio is doing. A
    // wired machine is wired whether or not wi-fi happens to be switched on.
    readonly property string wifiLabel: {
        var vpn = root.networkPopup ? root.networkPopup.netVpn : ""
        if (vpn && vpn !== "no" && vpn !== "")
            return "VPN"

        var devices = NetworkSystem.devices
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === "ethernet"
                    && devices[i].state.indexOf("connected") === 0)
                return "Wired"
        }
        return "Wi-Fi"
    }

    property bool micMuted: false

    Process {
        id: micToggleProc
        command: root.newUtill(["--togglemic"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text
                if (text.indexOf("off") !== -1) quickPanel.micMuted = true
                else if (text.indexOf("on") !== -1) quickPanel.micMuted = false
            }
        }
    }

    Process {
        id: micStateProc
        command: root.newUtill(["--getaudio"])
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(",")
                if (parts.length >= 4)
                    quickPanel.micMuted = parts[3].indexOf("off") !== -1
            }
        }
    }

    Process {
        id: btPowerProc
        command: root.newUtill(["--btpower",
            quickPanel.btPowered ? "off" : "on"])
        stdout: StdioCollector {
            onStreamFinished: btStateProc.running = true
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
        // Centred on the bar. It is a general menu now, not a popup belonging
        // to one button, so it no longer follows whatever opened it.
        quickPanel.anchor.rect.x =
            (mainWindow.width / 2) - (quickPanel.implicitWidth / 2)

        quickPanel.isClosing = false
        background.opacity = 0
        quickPanel.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        StatsSystem.active = true
        NetworkSystem.refresh()

        // ddcutil takes a noticeable moment per display, and the panel was
        // firing it on every open. The values do not change behind our back,
        // so a recent read is reused.
        if (Date.now() - quickPanel.lastBrightnessRead > 30000) {
            quickPanel.lastBrightnessRead = Date.now()
            BrightnessSystem.read()
        }
    }

    function forceClose() {
        if (quickPanel.isClosing || !quickPanel.visible)
            return
        quickPanel.isClosing = true
        focusGrab.active = false
        StatsSystem.active = false
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

        GridLayout {
            id: content
            x: 14
            y: 14
            width: background.width - 28
            columns: 4
            columnSpacing: Theme.gap
            rowSpacing: Theme.gap

            // ## Who and how long
            // Everything below sits on one two column grid. Full width controls
            // span both columns, tiles take one — so nothing needs a section
            // heading to explain where it belongs.

            // ## Session
            // Its own block at the top. Identity on one line, readings on the
            // next — sharing a single row left the panels too narrow to show
            // either their icon or their value.

            Rectangle {
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 142
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.scrimBase, 0.45)
                border.width: Theme.borderWidth
                border.color: Theme.alpha(Theme.textBase, 0.12)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            radius: 19
                            color: Theme.alpha(Theme.accent, 0.25)
                            border.width: Theme.borderWidth
                            border.color: Theme.accentLine

                            Text {
                                anchors.centerIn: parent
                                text: quickPanel.userName.charAt(0).toUpperCase()
                                color: Theme.accentText
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                font.weight: 700
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: quickPanel.userName
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: 700
                            }

                            Text {
                                Layout.fillWidth: true
                                text: quickPanel.hostName !== ""
                                    ? quickPanel.hostName : "this machine"
                                elide: Text.ElideRight
                                color: Theme.textMute
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.descSize
                            }
                        }

                        Text {
                            text: "up " + quickPanel.uptime
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.valueSize
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        PanelGraph {
                            iconName: "settings"
                            caption: "CPU"
                            value: StatsSystem.cpuText
                            level: StatsSystem.cpu
                            history: StatsSystem.cpuHistory
                        }

                        PanelGraph {
                            iconName: "download"
                            caption: "MEMORY"
                            value: StatsSystem.memoryText
                            level: StatsSystem.memoryFraction
                            history: StatsSystem.memoryHistory
                        }

                        PanelStat {
                            Layout.preferredHeight: 68
                            iconName: "notify"
                            caption: "NOTIFICATIONS"
                            value: {
                                if (!root.notifyServer)
                                    return "unavailable"
                                var count = root.notifyServer
                                    .trackedNotifications.values.length
                                if (count === 0)
                                    return "none waiting"
                                return count + (count === 1 ? " waiting" : " waiting")
                            }
                            interactive: true
                            onActivated: {
                                quickPanel.forceClose()
                                if (root.notificationsPanel)
                                    root.notificationsPanel.forceOpen(
                                        root.menuAnchor ? root.menuAnchor
                                                        : mainWindow.settingsAnchor)
                            }
                        }

                        PanelStat {
                            Layout.preferredHeight: 68
                            iconName: "apps"
                            caption: "WINDOWS"
                            value: HyprlandSystem.windows.length + " open"
                            interactive: true
                            onActivated: {
                                quickPanel.forceClose()
                                root.overview.open()
                            }
                        }

                        PanelStat {
                            Layout.preferredHeight: 68
                            iconName: "download"
                            caption: "UPDATES"
                            value: PackageSystem.scanned
                                ? (PackageSystem.updateCount > 0
                                    ? PackageSystem.updateCount + " pending"
                                    : "up to date")
                                : "not checked"
                            interactive: true
                            onActivated: quickPanel.openTarget("packages")
                        }
                    }
                }
            }

            // ## Media
            // One element: what is playing, and the transport for it.

            Rectangle {
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                visible: root.media && (root.media.status === "Playing"
                                        || root.media.status === "Paused")
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.scrimBase, 0.35)
                border.width: Theme.borderWidth
                border.color: Theme.alpha(Theme.textBase, 0.10)

                Rectangle {
                    id: artBox
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.textBase, 0.08)
                    clip: true

                    Image {
                        anchors.fill: parent
                        visible: source != ""
                        source: root.media && root.media.artUrl
                            ? root.media.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 96
                        sourceSize.height: 96
                        smooth: true
                        asynchronous: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !(root.media && root.media.artUrl)
                        iconName: "music_note_single"
                        iconSize: 20
                        color: Theme.accentIcon
                    }
                }

                Column {
                    anchors.left: artBox.right
                    anchors.leftMargin: 12
                    anchors.right: transport.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    ScrollingText {
                        width: parent.width
                        text: root.media && root.media.title ? root.media.title : ""
                        color: Theme.text
                        pixelSize: Theme.labelSize
                        weight: 700
                    }

                    ScrollingText {
                        width: parent.width
                        text: root.media && root.media.artist ? root.media.artist : ""
                        color: Theme.textMute
                        pixelSize: Theme.descSize
                        weight: 500
                    }
                }

                Row {
                    id: transport
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    IconButton {
                        iconName: "music_prev"
                        iconSize: 18
                        color: Theme.textDim
                        onClicked: root.execute(root.cmd("media_previous"))
                    }

                    IconButton {
                        iconName: root.media && root.media.status === "Playing"
                            ? "music_pause" : "music_play"
                        iconSize: 24
                        color: Theme.accentIcon
                        onClicked: root.execute(root.cmd("media_toggle"))
                    }

                    IconButton {
                        iconName: "music_skip"
                        iconSize: 18
                        color: Theme.textDim
                        onClicked: root.execute(root.cmd("media_next"))
                    }
                }
            }

            PanelSlider {
                Layout.columnSpan: 4
                iconName: BrightnessSystem.value > 60 ? "backlight_high"
                    : BrightnessSystem.value > 20 ? "backlight_low"
                                                  : "backlight_off"
                label: "Brightness"
                enabled: BrightnessSystem.available
                value: BrightnessSystem.value
                onMoved: (v) => BrightnessSystem.set(v)
            }

            PanelModeRow {
                Layout.columnSpan: 4
                value: root.wallpaperMode
                modes: [
                    { label: "Automatic", detail: "Follows the clock",
                      icon: "history", tint: Theme.accent },
                    { label: "Day", detail: "Light wallpapers",
                      icon: "light_mode", tint: "#f0b429" },
                    { label: "Night", detail: "Dark wallpapers",
                      icon: "dark_mode", tint: "#6d8fd6" }
                ]
                onPicked: (value) => {
                    root.wallpaperMode = value
                    root.settings.wallpapers.wallpaperMode = value
                    root.saveSettings()
                    root.nextWallpaper()
                }
            }

            // ## Toggles and shortcuts, on the same grid

            QuickTile {
                Layout.fillWidth: true
                iconName: "dark_mode"
                label: "Theater"
                toggle: true
                active: root.theaterMode
                onActivated: root.setTheaterMode(!root.theaterMode)
            }

            QuickTile {
                Layout.fillWidth: true
                iconName: "hide"
                label: "Gaming"
                toggle: true
                active: root.settings.gaming ? root.settings.gaming.enabled === true : false
                onActivated: {
                    if (!root.settings.gaming)
                        root.settings.gaming = ({ enabled: true, apps: [] })
                    else
                        root.settings.gaming.enabled = !root.settings.gaming.enabled
                    root.saveSettings()
                }
            }

            // ## Radios
            // Wi-Fi being off is not necessarily a problem, so the tile says
            // why rather than just looking disabled.

            QuickTile {
                Layout.fillWidth: true
                iconName: quickPanel.wifiIcon
                label: quickPanel.wifiLabel
                toggle: true
                active: NetworkSystem.wifiEnabled
                onActivated: NetworkSystem.setWifi(!NetworkSystem.wifiEnabled)
            }

            QuickTile {
                Layout.fillWidth: true
                iconName: "bluetooth"
                label: "Bluetooth"
                toggle: true
                active: quickPanel.btPowered
                onActivated: btPowerProc.running = true
            }

            QuickTile {
                Layout.fillWidth: true
                iconName: quickPanel.micMuted ? "microphone_mute" : "microphone"
                label: quickPanel.micMuted ? "Mic Off" : "Mic"
                toggle: true
                active: !quickPanel.micMuted
                onActivated: micToggleProc.running = true
            }

            QuickTile {
                Layout.fillWidth: true
                iconName: "refresh"
                label: "Wallpaper"
                onActivated: root.nextWallpaper()
            }

            Repeater {
                model: [
                    { icon: "terminal", key: "terminal", label: "Terminal" },
                    { icon: "open_folder", key: "files", label: "Files" },
                    { icon: "screenshot", key: "screenshot", label: "Screenshot" },
                    { icon: "filter", key: "colorpicker", label: "Colour" },
                    { icon: "settings", key: "config_quickshell", label: "Config" },
                    { icon: "restart", key: "restart_shell", label: "Restart" }
                ]

                delegate: QuickTile {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.icon
                    label: modelData.label
                    onActivated: {
                        root.cmdExec(modelData.key)
                        quickPanel.forceClose()
                    }
                }
            }

            // ## Drives

            Repeater {
                model: quickPanel.usbDrives

                delegate: PanelRow {
                    required property var modelData

                    Layout.columnSpan: 4
                    navigates: true
                    iconName: "download"
                    label: modelData.label
                    detail: modelData.mountpoint

                    onActivated: {
                        root.cmdExec("files_open", { "path": modelData.mountpoint })
                        quickPanel.forceClose()
                    }
                }
            }

            // ## Recent
            // What this shell has launched, newest first

            Repeater {
                // Three at most. More than that grew the grid past the panel
                // and pushed the toolbar out of view.
                model: RecentSystem.combined.slice(0, 3)

                delegate: PanelRow {
                    required property var modelData

                    readonly property bool isApp: modelData.kind === "app"

                    Layout.columnSpan: 4
                    navigates: true

                    // An app shows its own icon; a command shows a terminal
                    // glyph, so the two are never confused
                    iconSource: isApp && modelData.icon !== ""
                        ? RecentSystem.iconFor(modelData.icon) : ""
                    iconName: isApp ? "open_app" : "terminal"

                    label: modelData.label
                    detail: (isApp ? "app" : "command")
                        + "  ·  " + RecentSystem.relative(modelData.at)

                    onActivated: {
                        quickPanel.forceClose()
                        root.execute(modelData.payload.split(" "))
                    }
                }
            }

            // ## Toolbar
            // Anything that leaves this menu for somewhere else lives here, so
            // the grid above stays controls you can act on without navigating.

            Rectangle {
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Layout.topMargin: 4
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.textBase, 0.07)
                border.width: Theme.borderWidth
                border.color: Theme.alpha(Theme.textBase, 0.10)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "audio", icon: "media_output", label: "Audio" },
                            { key: "network", icon: "wired", label: "Network" },
                            { key: "bluetooth", icon: "bluetooth", label: "Bluetooth" },
                            { key: "settings", icon: "settings", label: "All Settings" },
                            { key: "power", icon: "power", label: "Power" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool danger: modelData.key === "power"

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: toolArea.containsMouse
                                ? (danger ? Theme.alpha(Theme.danger, 0.24)
                                          : Theme.alpha(Theme.accent, 0.20))
                                : "transparent"

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    iconName: modelData.icon
                                    iconSize: 18
                                    color: parent.parent.danger && toolArea.containsMouse
                                        ? Theme.danger : Theme.accentIcon
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.descSize
                                }
                            }

                            MouseArea {
                                id: toolArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: quickPanel.openTarget(modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }

    signal openPower()
    signal openFullSettings()

    // Opens the settings window on a named page, or wherever it was last
    signal openSettingsPage(string page)

    function openTarget(key) {
        quickPanel.forceClose()

        if (key === "settings") {
            quickPanel.openSettingsPage("")
            return
        }
        if (key === "packages") {
            quickPanel.openSettingsPage("packages")
            return
        }
        if (key === "power") {
            quickPanel.openPower()
            return
        }

        var target = key === "audio" ? root.audioPopup
            : key === "network" ? root.networkPopup
                                : root.bluetoothPopup
        if (!target)
            return

        target.backTarget = quickPanel
        target.forceOpen(mainWindow.settingsAnchor)
    }
}
