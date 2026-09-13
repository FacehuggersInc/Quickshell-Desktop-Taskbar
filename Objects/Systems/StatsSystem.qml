pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU and memory, read straight from /proc. No subprocess, the same way the
// network meter works.
QtObject {
    id: sys

    property real cpu: 0
    property real memoryUsed: 0
    property real memoryTotal: 0

    property var cpuHistory: []
    property var memoryHistory: []

    readonly property int historyLength: 24

    readonly property real memoryFraction:
        sys.memoryTotal > 0 ? sys.memoryUsed / sys.memoryTotal : 0

    readonly property string memoryText:
        sys.memoryTotal > 0
            ? (sys.memoryUsed / 1048576).toFixed(1) + " / "
              + (sys.memoryTotal / 1048576).toFixed(0) + " GB"
            : "…"

    readonly property string cpuText: Math.round(sys.cpu * 100) + "%"

    // Previous jiffies, so the delta is a real utilisation rather than the
    // average since boot
    property real lastBusy: 0
    property real lastTotal: 0

    function push(list, value) {
        var next = list.slice()
        next.push(value)
        while (next.length > sys.historyLength)
            next.shift()
        return next
    }

    function readCpu(text) {
        var lines = String(text).split("\n")
        if (lines.length === 0)
            return

        var parts = lines[0].trim().split(/\s+/)
        if (parts.length < 5 || parts[0] !== "cpu")
            return

        var total = 0
        for (var i = 1; i < parts.length; i++)
            total += parseFloat(parts[i]) || 0

        var idle = (parseFloat(parts[4]) || 0) + (parseFloat(parts[5]) || 0)
        var busy = total - idle

        if (sys.lastTotal > 0) {
            var deltaTotal = total - sys.lastTotal
            var deltaBusy = busy - sys.lastBusy
            if (deltaTotal > 0) {
                sys.cpu = Math.max(0, Math.min(1, deltaBusy / deltaTotal))
                sys.cpuHistory = sys.push(sys.cpuHistory, sys.cpu)
            }
        }

        sys.lastTotal = total
        sys.lastBusy = busy
    }

    function readMemory(text) {
        var total = 0
        var available = 0
        var lines = String(text).split("\n")

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("MemTotal:") === 0)
                total = parseFloat(line.replace(/[^0-9]/g, "")) || 0
            else if (line.indexOf("MemAvailable:") === 0)
                available = parseFloat(line.replace(/[^0-9]/g, "")) || 0
            if (total > 0 && available > 0)
                break
        }

        if (total <= 0)
            return

        sys.memoryTotal = total
        sys.memoryUsed = total - available
        sys.memoryHistory = sys.push(sys.memoryHistory, sys.memoryFraction)
    }

    property FileView cpuFile: FileView {
        path: "/proc/stat"
        onLoaded: sys.readCpu(this.text())
    }

    property FileView memoryFile: FileView {
        path: "/proc/meminfo"
        onLoaded: sys.readMemory(this.text())
    }

    property bool active: false

    property Timer poll: Timer {
        interval: 1500
        repeat: true
        running: sys.active
        triggeredOnStart: true
        onTriggered: {
            sys.cpuFile.reload()
            sys.memoryFile.reload()
        }
    }
}
