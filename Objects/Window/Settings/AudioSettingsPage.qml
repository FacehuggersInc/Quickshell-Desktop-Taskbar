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

    // ## Devices
    // Live from wpctl, so this cannot be a static schema item

    property var outputOptions: []
    property var inputOptions: []
    property int outputCurrent: -1
    property int inputCurrent: -1

    Process {
        id: devicesProc
        property var outputs: []
        property var inputs: []
        command: root.newUtill(["--getaudiodevices"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                devicesProc.outputs = []
                devicesProc.inputs = []
                var devices = this.text.split("|")
                for (var i = 0; i < devices.length; i++) {
                    var parts = devices[i].split(",")
                    if (parts.length < 4) continue
                    if (parts[1].includes("output")) devicesProc.outputs.push(devices[i])
                    else if (parts[1].includes("input")) devicesProc.inputs.push(devices[i])
                }
                page.rebuild()
            }
        }
    }

    function parse(items) {
        var options = []
        var current = -1
        for (var i = 0; i < items.length; i++) {
            var parts = items[i].split(",")
            options.push({ label: parts[3], value: parseInt(parts[0]) })
            if (parts[2].includes("True")) current = parseInt(parts[0])
        }
        return { options: options, current: current }
    }

    function rebuild() {
        var out = page.parse(devicesProc.outputs)
        page.outputOptions = out.options
        page.outputCurrent = out.current

        var inp = page.parse(devicesProc.inputs)
        page.inputOptions = inp.options
        page.inputCurrent = inp.current
    }

    function refresh() {
        if (!devicesProc.running) devicesProc.running = true
    }

    function setDefault(id) {
        root.execute(root.cmd("audio_set_default", { "index": id }))
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: page.refresh()
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Devices"
    }

    SettingRow {
        Layout.fillWidth: true
        iconName: "media_output"
        label: "Output Device"
        description: page.outputOptions.length + " available"

        SelectBox {
            width: 320
            options: page.outputOptions
            value: page.outputCurrent
            placeholder: "No outputs"
            onPicked: (v) => page.setDefault(v)
        }
    }

    SettingRow {
        Layout.fillWidth: true
        iconName: "media_input"
        label: "Input Device"
        description: page.inputOptions.length + " available"

        SelectBox {
            width: 320
            options: page.inputOptions
            value: page.inputCurrent
            placeholder: "No inputs"
            onPicked: (v) => page.setDefault(v)
        }
    }

    SettingRow {
        Layout.fillWidth: true
        iconName: "refresh"
        label: "Rescan Devices"
        description: "Re-read the pipewire device list"

        Rectangle {
            width: 96
            height: Theme.controlHeight
            radius: Theme.radiusSmall
            color: rescanArea.containsMouse ? Theme.alpha(Theme.accent, 0.22)
                                            : Theme.alpha(Theme.textBase, 0.10)
            border.width: Theme.borderWidth
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: "Rescan"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.valueSize
                font.weight: 600
            }

            MouseArea {
                id: rescanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.refresh()
            }
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Media Commands"
    }

    Repeater {
        model: [
            { key: "audio_set_volume", label: "Set Volume" },
            { key: "audio_set_default", label: "Set Default Device" },
            { key: "media_previous", label: "Previous Track" },
            { key: "media_toggle", label: "Play / Pause" },
            { key: "media_next", label: "Next Track" }
        ]

        delegate: SettingRow {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.label
            stacked: true

            InputField {
                width: parent.width
                text: root.settings.commands[modelData.key] || ""
                onCommitted: (v) => {
                    root.settings.commands[modelData.key] = v
                    root.saveSettings()
                }
            }
        }
    }
}
