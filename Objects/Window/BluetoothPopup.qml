import Quickshell
import Quickshell.Wayland
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
import qs.Objects.Window
import qs.Objects.Widgets
import qs.Objects.Theme

PopupWindow {
    id: bluetoothPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.popupOffset(implicitHeight)

    property int panelWidth: 420
    property int panelHeight: Math.min(Screen.height - mainWindow.height - 20, 680)

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property Region glassBlurRegion: Region { item: background }
    BackgroundEffect.blurRegion:
        (Theme.glass && Theme.blurMode === "protocol") ? glassBlurRegion : null

    property bool isClosing: false

    // ## Back
    // Set when the quick panel opened this, so there is a way to return

    property var backTarget: null

    function goBack() {
        var target = bluetoothPopup.backTarget
        bluetoothPopup.backTarget = null
        bluetoothPopup.forceClose()
        if (target && mainWindow.settingsAnchor)
            target.forceOpen(mainWindow.settingsAnchor)
    }

    property bool powered: false
    property bool scanning: false
    property var pairedDevices: []
    property var scanResults: []
    property string connectingMac: ""   // MAC of device currently connecting
    property real connectingRotation: 0  // shared rotation value for all spin icons

    // Root-level timer drives rotation independently of popup visibility
    Timer {
        id: spinTimer
        interval: 16   // ~60fps
        repeat: true
        running: bluetoothPopup.connectingMac !== ""
        onTriggered: bluetoothPopup.connectingRotation = (bluetoothPopup.connectingRotation + 6) % 360
    }

    // ── Animations ────────────────────────────────────────────────
    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (bluetoothPopup.isClosing) {
                bluetoothPopup.visible = false
                bluetoothPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ bluetoothPopup ]
        onCleared: {
            alphaAnim.stop()
            bluetoothPopup.isClosing = false
            bluetoothPopup.visible = false
            background.opacity = 0
        }
    }

    // ── Timers ────────────────────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: 3000
        repeat: true
        running: false
        onTriggered: {
            fetchState()
            fetchDevices()
            if (bluetoothPopup.scanning) fetchScanResults()
        }
    }

    Timer {
        id: scanTimeout
        interval: 12000
        repeat: false
        onTriggered: {
            bluetoothPopup.scanning = false
            scanProc.command = root.newUtill(["--btscan", "off"])
            scanProc.running = true
            scanStatusText.text = "Scan complete"
        }
    }

    // ── Processes ─────────────────────────────────────────────────
    Process {
        id: stateProc
        command: root.newUtill(["--btstate"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (!text) return
                var obj = {}
                text.split(",").forEach(function(pair) {
                    var kv = pair.split(":")
                    if (kv.length >= 2) obj[kv[0]] = kv.slice(1).join(":")
                })
                bluetoothPopup.powered = obj["powered"] === "yes"
                bluetoothPopup.scanning = obj["scanning"] === "yes"
                powerLabel.text = bluetoothPopup.powered ? "On" : "Off"
                scanStatusText.text = bluetoothPopup.scanning ? "Scanning..." : ""
            }
        }
    }

    Process {
        id: devicesProc
        command: root.newUtill(["--btdevices"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                bluetoothPopup.pairedDevices = []
                if (text === "none" || text === "") return
                var lines = text.split("\n")
                var devs = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length < 6) continue
                    devs.push({
                        mac:       parts[0],
                        name:      parts[1],
                        alias:     parts[2] || parts[1],
                        connected: parts[3] === "yes",
                        battery:   parts[4],
                        icon:      parts[5]
                    })
                }
                bluetoothPopup.pairedDevices = devs
            }
        }
    }

    Process {
        id: scanResultsProc
        command: root.newUtill(["--btscanresults"])
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                bluetoothPopup.scanResults = []
                if (text === "none" || text === "") return
                var lines = text.split("\n")
                var results = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length < 2) continue
                    results.push({ mac: parts[0], name: parts[1] })
                }
                bluetoothPopup.scanResults = results
            }
        }
    }

    Process { id: powerProc;      stdout: StdioCollector { onStreamFinished: { fetchState(); fetchDevices() } } }
    Process {
        id: connectProc
        stdout: StdioCollector {
            onStreamFinished: {
                bluetoothPopup.connectingMac = ""
                fetchDevices()
            }
        }
    }
    Process {
        id: disconnectProc
        stdout: StdioCollector {
            onStreamFinished: {
                bluetoothPopup.connectingMac = ""
                fetchDevices()
            }
        }
    }
    Process { id: forgetProc;     stdout: StdioCollector { onStreamFinished: { fetchDevices() } } }
    Process { id: pairProc;       stdout: StdioCollector { onStreamFinished: { fetchDevices(); fetchScanResults() } } }
    Process { id: scanProc }

    // ── Data functions ────────────────────────────────────────────
    function fetchState()       { if (!stateProc.running)       stateProc.running = true }
    function fetchDevices()     { if (!devicesProc.running)     devicesProc.running = true }
    function fetchScanResults() { if (!scanResultsProc.running) scanResultsProc.running = true }

    function togglePower() {
        powerProc.command = root.newUtill(["--btpower", "toggle"])
        powerProc.running = true
    }

    function startScan() {
        if (!powered) return
        scanning = true
        scanStatusText.text = "Scanning..."
        scanProc.command = root.newUtill(["--btscan", "on"])
        scanProc.running = true
        scanTimeout.restart()
        fetchScanResults()
    }

    function connectDevice(mac, name) {
        bluetoothPopup.connectingMac = mac
        root.execute([
            "notify-send",
            "--app-name=Bluetooth",
            "--urgency=low",
            "Bluetooth",
            "Connecting to " + name + "..."
        ])
        connectProc.command = root.newUtill(["--btconnect", mac, name])
        connectProc.running = true
    }

    function disconnectDevice(mac, name) {
        bluetoothPopup.connectingMac = mac
        disconnectProc.command = root.newUtill(["--btdisconnect", mac, name])
        disconnectProc.running = true
    }

    function forgetDevice(mac, name) {
        forgetProc.command = root.newUtill(["--btforget", mac, name])
        forgetProc.running = true
    }

    function pairDevice(mac, name) {
        pairProc.command = root.newUtill(["--btpair", mac, name])
        pairProc.running = true
    }

    // ── Background ────────────────────────────────────────────────
    Rectangle {
        id: background

        // Back to quick settings
        Rectangle {
            visible: bluetoothPopup.backTarget !== null
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
                onClicked: bluetoothPopup.goBack()
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
            // Pushed clear of the back control rather than sitting under it
            anchors.topMargin: bluetoothPopup.backTarget !== null ? 38 : 12
            spacing: 8

            // ── Header ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                IconButton {
                    id: powerButton
                    iconName: bluetoothPopup.powered ? "bluetooth" : "bluetooth_disabled"
                    iconSize: 24
                    color: bluetoothPopup.powered
                        ? root.theme.primary
                        : "#666666"
                    tooltipText: "Toggle Bluetooth"
                    onClicked: togglePower()
                }

                Text {
                    text: "Bluetooth"
                    color: root.theme.text
                    font.family: root.settings.fontFamily
                    font.weight: 700
                    font.pixelSize: 18
                    Layout.fillWidth: true
                }

                Text {
                    id: powerLabel
                    text: bluetoothPopup.powered ? "On" : "Off"
                    color: bluetoothPopup.powered
                        ? root.theme.primary
                        : "#666666"
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    font.weight: 600
                }

                IconButton {
                    iconName: bluetoothPopup.scanning ? "bluetooth_searching" : "search"
                    iconSize: 20
                    color: bluetoothPopup.scanning
                        ? root.theme.primary
                        : root.theme.text
                    tooltipText: bluetoothPopup.scanning ? "Scanning..." : "Scan for devices"
                    opacity: bluetoothPopup.powered ? 1.0 : 0.3
                    onClicked: if (bluetoothPopup.powered) startScan()
                }
            }

            // Scan status
            Text {
                id: scanStatusText
                text: ""
                color: root.theme.primary
                font.family: root.settings.fontFamily
                font.pixelSize: 12
                opacity: 0.8
                visible: text !== ""
                Layout.fillWidth: true

                SequentialAnimation on opacity {
                    running: bluetoothPopup.scanning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700 }
                    NumberAnimation { to: 1.0; duration: 700 }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.theme.text
                opacity: 0.1
            }

            // ── Scrollable content ────────────────────────────────
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                contentHeight: contentColumn.implicitHeight
                clip: true

                ColumnLayout {
                    id: contentColumn
                    width: panelWidth - 24
                    spacing: 4

                    // ── Paired devices ────────────────────────────
                    SectionLabel {
                        text: "Paired Devices"
                        Layout.fillWidth: true
                        visible: bluetoothPopup.pairedDevices.length > 0
                    }

                    Text {
                        text: bluetoothPopup.powered
                            ? "No paired devices"
                            : "Bluetooth is off"
                        color: root.theme.text
                        opacity: 0.4
                        font.family: root.settings.fontFamily
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: bluetoothPopup.pairedDevices.length === 0
                        Layout.topMargin: 8
                    }

                    Repeater {
                        model: bluetoothPopup.pairedDevices

                        delegate: RoundedBlock {
                            id: pairedRow
                            required property var modelData

                            readonly property bool connecting:
                                bluetoothPopup.connectingMac === modelData.mac

                            Layout.fillWidth: true
                            color: Theme.alpha(Theme.textBase, 0.08)
                            alpha: 1.0
                            radius: Theme.radiusSmall
                            border: true
                            highlight: false
                            elevated: false
                            sidePadding: 10
                            tbPadding: 8

                            RowLayout {
                                width: parent.width - 20
                                spacing: Theme.gap

                                Icon {
                                    iconName: modelData.connected
                                        ? "bluetooth_connected" : "bluetooth"
                                    iconSize: 18
                                    color: modelData.connected ? Theme.accentIcon : Theme.textMute
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.alias !== modelData.name
                                            ? modelData.alias : modelData.name
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.weight: 600
                                        font.pixelSize: Theme.labelSize
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        spacing: 8

                                        Text {
                                            text: modelData.mac
                                            color: Theme.textMute
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.descSize
                                        }

                                        Text {
                                            visible: modelData.battery !== ""
                                            text: modelData.battery + "%"
                                            color: {
                                                var b = parseInt(modelData.battery)
                                                if (b <= 20) return Theme.danger
                                                if (b <= 50) return Theme.warn
                                                return Theme.ok
                                            }
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.descSize
                                            font.weight: 600
                                        }
                                    }
                                }

                                ActionButton {
                                    label: pairedRow.connecting
                                        ? "Connecting"
                                        : (modelData.connected ? "Disconnect" : "Connect")
                                    tone: modelData.connected ? "neutral" : "accent"
                                    busy: pairedRow.connecting
                                    onActivated: {
                                        if (modelData.connected)
                                            disconnectDevice(modelData.mac, modelData.alias)
                                        else
                                            connectDevice(modelData.mac, modelData.alias)
                                    }
                                }

                                ActionButton {
                                    label: "Forget"
                                    tone: "danger"
                                    onActivated: forgetDevice(modelData.mac, modelData.alias)
                                }
                            }
                        }
                    }

                    // ── Scan results ──────────────────────────────
                    SectionLabel {
                        text: "Nearby Devices"
                        Layout.fillWidth: true
                        visible: bluetoothPopup.scanResults.length > 0
                    }

                    Repeater {
                        model: bluetoothPopup.scanResults

                        delegate: RoundedBlock {
                            required property var modelData

                            Layout.fillWidth: true
                            color: Theme.alpha(Theme.textBase, 0.05)
                            alpha: 1.0
                            radius: Theme.radiusSmall
                            border: true
                            highlight: false
                            elevated: false
                            sidePadding: 10
                            tbPadding: 8

                            RowLayout {
                                width: parent.width - 20
                                spacing: Theme.gap

                                Icon {
                                    iconName: "bluetooth_searching"
                                    iconSize: 18
                                    color: Theme.textMute
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.weight: 500
                                        font.pixelSize: Theme.labelSize
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.mac
                                        color: Theme.textMute
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.descSize
                                    }
                                }

                                ActionButton {
                                    label: "Pair"
                                    tone: "accent"
                                    onActivated: pairDevice(modelData.mac, modelData.name)
                                }
                            }
                        }
                    }

                    Item { implicitHeight: 8 }
                }
            }
        }
    }

    // ── Open / close API ─────────────────────────────────────────
    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        bluetoothPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) {
            alphaAnim.stop()
            isClosing = false
        }
        updatePosition(widget)
        background.opacity = 0
        bluetoothPopup.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        fetchState()
        fetchDevices()
        refreshTimer.start()
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
        focusGrab.active = false
        refreshTimer.stop()
        scanTimeout.stop()
    }

    function toggle(widget) {
        // Opened from the bar, so there is nothing to go back to
        bluetoothPopup.backTarget = null
        if (!bluetoothPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}