import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets

IconButton {
    id: bluetoothWidget
    iconName: "bluetooth"
    iconSize: 25
    tooltipText: "Bluetooth"
    color: root.theme.secondary

    property bool powered: false
    property int connectedCount: 0
    property string connectedName: ""


    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: updateState()
    }

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
                bluetoothWidget.powered = obj["powered"] === "yes"
                bluetoothWidget.connectedCount = parseInt(obj["connected"] || "0")
                bluetoothWidget.connectedName = obj["device"] || ""
                bluetoothWidget.setIcon(bluetoothWidget.powered ? "bluetooth" : "bluetooth_disabled")
                bluetoothWidget.setColor(bluetoothWidget.powered ? root.theme.primary : root.theme.secondary)
                bluetoothWidget.tooltipText = bluetoothWidget.powered
                    ? "Bluetooth: On"
                    : "Bluetooth: Off"
            }
        }
    }

    function updateState() {
        if (!stateProc.running) stateProc.running = true
    }

    Component.onCompleted: {
        root.bluetoothWidget = bluetoothWidget
        updateState()
    }

    onClicked: {
        if (root.bluetoothPopup) root.bluetoothPopup.toggle(bluetoothWidget)
    }
}