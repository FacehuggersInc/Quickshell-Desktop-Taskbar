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
    id: bluetoothPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth: 420
    property int panelHeight: Math.min(Screen.height - mainWindow.height - 20, 680)

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property bool isClosing: false
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
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
                        ? root.settings.theme.primary
                        : "#666666"
                    tooltipText: "Toggle Bluetooth"
                    onClicked: togglePower()
                }

                Text {
                    text: "Bluetooth"
                    color: root.settings.theme.text
                    font.family: root.settings.fontFamily
                    font.weight: 700
                    font.pixelSize: 18
                    Layout.fillWidth: true
                }

                Text {
                    id: powerLabel
                    text: bluetoothPopup.powered ? "On" : "Off"
                    color: bluetoothPopup.powered
                        ? root.settings.theme.primary
                        : "#666666"
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    font.weight: 600
                }

                IconButton {
                    iconName: bluetoothPopup.scanning ? "bluetooth_searching" : "search"
                    iconSize: 20
                    color: bluetoothPopup.scanning
                        ? root.settings.theme.primary
                        : root.settings.theme.text
                    tooltipText: bluetoothPopup.scanning ? "Scanning..." : "Scan for devices"
                    opacity: bluetoothPopup.powered ? 1.0 : 0.3
                    onClicked: if (bluetoothPopup.powered) startScan()
                }
            }

            // Scan status
            Text {
                id: scanStatusText
                text: ""
                color: root.settings.theme.primary
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
                color: root.settings.theme.text
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
                    TextDivider {
                        dividerText: "Paired Devices"
                        dividerHeight: 2
                        Layout.fillWidth: true
                        visible: bluetoothPopup.pairedDevices.length > 0
                    }

                    Text {
                        text: bluetoothPopup.powered
                            ? "No paired devices"
                            : "Bluetooth is off"
                        color: root.settings.theme.text
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
                            required property var modelData
                            Layout.fillWidth: true
                            color: root.settings.theme.surface
                            alpha: 1.0
                            radius: 10
                            sidePadding: 10
                            tbPadding: 8

                            RowLayout {
                                width: parent.width - 20
                                spacing: 10

                                IconButton {
                                    iconName: modelData.connected ? "bluetooth_connected" : "bluetooth"
                                    iconSize: 16
                                    tooltipText: modelData.connected ? "Connected" : "Not connected"
                                    color: modelData.connected
                                        ? root.settings.theme.primary
                                        : "#444444"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.alias !== modelData.name
                                            ? modelData.alias
                                            : modelData.name
                                        color: root.settings.theme.text
                                        font.family: root.settings.fontFamily
                                        font.weight: 600
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: modelData.mac
                                            color: root.settings.theme.text
                                            opacity: 0.4
                                            font.family: root.settings.fontFamily
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            visible: modelData.battery !== ""
                                            text: modelData.battery !== ""
                                                ? "🔋 " + modelData.battery + "%"
                                                : ""
                                            color: {
                                                var b = parseInt(modelData.battery)
                                                if (b <= 20) return "#ff4a4a"
                                                if (b <= 50) return "#ffaa00"
                                                return root.settings.theme.primary
                                            }
                                            font.family: root.settings.fontFamily
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                // Connect / Disconnect button — shows spinner while connecting
                                RoundButton {
                                    id: connectBtn
                                    property bool isConnecting: bluetoothPopup.connectingMac === modelData.mac
                                    text: isConnecting ? "..." : (modelData.connected ? "Disconnect" : "Connect")
                                    enabled: !isConnecting
                                    font.family: root.settings.fontFamily
                                    font.pixelSize: 12
                                    padding: 4
                                    horizontalPadding: 10

                                    contentItem: RowLayout {
                                        spacing: 4
                                        // Spinning icon while connecting
                                        Image {
                                            visible: connectBtn.isConnecting
                                            source: root.iconSource("sync")
                                            width: 14; height: 14
                                            sourceSize.width: 14; sourceSize.height: 14
                                            fillMode: Image.PreserveAspectFit

                                            RotationAnimation on rotation {
                                                running: connectBtn.isConnecting
                                                loops: Animation.Infinite
                                                from: 0; to: 360
                                                duration: 1000
                                            }
                                        }
                                        Text {
                                            text: connectBtn.text
                                            font: connectBtn.font
                                            color: root.settings.theme.text
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    background: Rectangle {
                                        radius: 6
                                        color: connectBtn.isConnecting
                                            ? root.settings.theme.surface
                                            : modelData.connected
                                                ? "#555555"
                                                : root.settings.theme.primary
                                        opacity: connectBtn.isConnecting ? 0.5 : 0.7
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    onClicked: {
                                        if (modelData.connected)
                                            disconnectDevice(modelData.mac, modelData.alias)
                                        else
                                            connectDevice(modelData.mac, modelData.alias)
                                    }
                                }

                                // Forget button
                                IconButton {
                                    iconName: "delete"
                                    iconSize: 16
                                    color: "#e05555"
                                    tooltipText: "Forget device"
                                    onClicked: forgetDevice(modelData.mac, modelData.alias)
                                }
                            }
                        }
                    }

                    // ── Scan results ──────────────────────────────
                    TextDivider {
                        dividerText: "Nearby Devices"
                        dividerHeight: 2
                        Layout.fillWidth: true
                        visible: bluetoothPopup.scanResults.length > 0
                    }

                    Repeater {
                        model: bluetoothPopup.scanResults
                        delegate: RoundedBlock {
                            required property var modelData
                            Layout.fillWidth: true
                            color: root.settings.theme.surface
                            alpha: 0.6
                            radius: 10
                            sidePadding: 10
                            tbPadding: 8

                            RowLayout {
                                width: parent.width - 20
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        color: root.settings.theme.text
                                        font.family: root.settings.fontFamily
                                        font.weight: 500
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.mac
                                        color: root.settings.theme.text
                                        opacity: 0.4
                                        font.family: root.settings.fontFamily
                                        font.pixelSize: 11
                                    }
                                }

                                RoundButton {
                                    text: "Pair"
                                    font.family: root.settings.fontFamily
                                    font.pixelSize: 12
                                    padding: 4
                                    horizontalPadding: 10
                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: root.settings.theme.text
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    background: Rectangle {
                                        radius: 6
                                        color: root.settings.theme.primary
                                        opacity: 0.7
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    onClicked: pairDevice(modelData.mac, modelData.name)
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
        if (!bluetoothPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}