import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme

ColumnLayout {
    id: page
    spacing: 0

    property bool powered: false
    property bool scanning: false
    property var devices: []

    Process {
        id: stateProc
        command: root.newUtill(["--btstate"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(",")
                for (var i = 0; i < parts.length; i++) {
                    var kv = parts[i].split(":")
                    if (kv[0] === "powered") page.powered = kv[1] === "yes"
                    if (kv[0] === "scanning") page.scanning = kv[1] === "yes"
                }
            }
        }
    }

    Process {
        id: devicesProc
        command: root.newUtill(["--btdevices"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var list = []
                var entries = this.text.trim().split("|")
                for (var i = 0; i < entries.length; i++) {
                    var parts = entries[i].split(",")
                    if (parts.length < 3) continue
                    list.push({
                        mac: parts[0],
                        name: parts[1],
                        connected: parts[2].toLowerCase().includes("yes"),
                        battery: parts.length > 3 ? parts[3] : ""
                    })
                }
                page.devices = list
            }
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: {
            if (!stateProc.running) stateProc.running = true
            if (!devicesProc.running) devicesProc.running = true
        }
    }

    function run(args) {
        actionProc.command = root.newUtill(args)
        actionProc.running = true
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                stateProc.running = true
                devicesProc.running = true
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Adapter"
    }

    SettingRow {
        Layout.fillWidth: true
        iconName: "bluetooth"
        label: "Bluetooth"
        description: page.powered ? "Adapter is on" : "Adapter is off"

        ToggleSwitch {
            checked: page.powered
            onToggled: (v) => page.run(["--btpower", v ? "on" : "off"])
        }
    }

    SettingRow {
        Layout.fillWidth: true
        iconName: "bluetooth_searching"
        label: "Scan for Devices"
        description: page.scanning ? "Scanning" : "Look for nearby devices"
        enabled: page.powered

        Rectangle {
            width: 96
            height: Theme.controlHeight
            radius: Theme.radiusSmall
            color: scanArea.containsMouse ? Theme.alpha(Theme.accent, 0.22)
                                          : Theme.alpha(Theme.textBase, 0.10)
            border.width: Theme.borderWidth
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: page.scanning ? "Scanning" : "Scan"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.valueSize
                font.weight: 600
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.run(["--btscan"])
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Paired Devices"
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: page.devices.length === 0
        text: page.powered ? "No paired devices" : "Turn the adapter on to see devices"
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    Repeater {
        model: page.devices

        delegate: SettingRow {
            required property var modelData

            Layout.fillWidth: true
            iconName: modelData.connected ? "bluetooth_connected" : "bluetooth"
            label: modelData.name
            description: modelData.mac
                + (modelData.battery !== "" ? "  ·  " + modelData.battery + "%" : "")

            Row {
                spacing: 6

                Rectangle {
                    width: 86
                    height: Theme.controlHeight
                    radius: Theme.radiusSmall
                    color: connectArea.containsMouse ? Theme.alpha(Theme.accent, 0.22)
                                                     : Theme.alpha(Theme.textBase, 0.10)
                    border.width: Theme.borderWidth
                    border.color: modelData.connected ? Theme.accentLine : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: modelData.connected ? "Disconnect" : "Connect"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                    }

                    MouseArea {
                        id: connectArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.run([
                            modelData.connected ? "--btdisconnect" : "--btconnect",
                            modelData.mac
                        ])
                    }
                }

                Rectangle {
                    width: 64
                    height: Theme.controlHeight
                    radius: Theme.radiusSmall
                    color: forgetArea.containsMouse ? Theme.alpha(Theme.danger, 0.22)
                                                    : Theme.alpha(Theme.textBase, 0.10)
                    border.width: Theme.borderWidth
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Forget"
                        color: forgetArea.containsMouse ? Theme.danger : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.valueSize
                    }

                    MouseArea {
                        id: forgetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.run(["--btforget", modelData.mac])
                    }
                }
            }
        }
    }
}
