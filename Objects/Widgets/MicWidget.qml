import Quickshell
import Quickshell.Io
import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

// Microphone mute toggle. Split out of the volume widget so it can be placed,
// removed or reordered on its own.
IconButton {
    id: micWidget

    property bool muted: false

    iconName: micWidget.muted ? "microphone_mute" : "microphone"
    iconSize: 20
    color: micWidget.muted ? Theme.danger : Theme.accentIcon
    tooltipText: micWidget.muted ? "Microphone muted" : "Microphone live"

    function applyState(text) {
        if (!text)
            return
        if (text.indexOf("off") !== -1)
            micWidget.muted = true
        else if (text.indexOf("on") !== -1)
            micWidget.muted = false
    }

    Process {
        id: micToggleProc
        command: root.newUtill(["--togglemic"])
        stdout: StdioCollector {
            onStreamFinished: micWidget.applyState(this.text)
        }
    }

    Process {
        id: micStateProc
        command: root.newUtill(["--getaudio"])
        stdout: StdioCollector {
            onStreamFinished: {
                // getaudio returns volume%,active,mic%,micactive
                var parts = this.text.trim().split(",")
                if (parts.length >= 4)
                    micWidget.applyState(parts[3])
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!micStateProc.running) micStateProc.running = true
        }
    }

    onClicked: {
        if (!micToggleProc.running) micToggleProc.running = true
    }
}
