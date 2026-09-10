pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: sys

    // ## State

    property int value: 50
    property bool available: false
    property bool ready: false
    property var displays: []

    // True from the first drag until the last write lands, so nothing
    // overwrites what the user is currently setting
    property bool holding: false

    property string utillInterpreter: "python3"
    property string utillPath: ""

    function command(args) {
        var out = [utillInterpreter, utillPath]
        for (var i = 0; i < args.length; i++)
            out.push(args[i])
        return out
    }

    // ## Read
    // ddcutil is slow enough that this runs once at startup rather than every
    // time a panel opens. Refresh explicitly if the monitors change.

    property Process statusProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (!text || text === "none") {
                    sys.available = false
                    sys.ready = true
                    return
                }

                var split = text.split("#")
                if (split.length < 2) {
                    sys.available = false
                    sys.ready = true
                    return
                }

                var names = []
                var entries = split[1].split("|")
                for (var i = 0; i < entries.length; i++) {
                    var parts = entries[i].split(":")
                    if (parts.length >= 3)
                        names.push({ display: parseInt(parts[0]), name: parts[2] })
                }

                sys.displays = names
                sys.available = names.length > 0
                if (!sys.holding)
                    sys.value = parseInt(split[0])
                sys.ready = true
            }
        }
    }

    property Process setProc: Process {}

    property Process refreshProc: Process {
        stdout: StdioCollector {
            onStreamFinished: sys.read()
        }
    }

    function read() {
        if (!utillPath || statusProc.running)
            return
        statusProc.command = sys.command(["--ddcstatus"])
        statusProc.running = true
    }

    function refresh() {
        if (!utillPath || refreshProc.running)
            return
        refreshProc.command = sys.command(["--ddcrefresh"])
        refreshProc.running = true
    }

    // ## Write
    // One call sets every display in parallel. Writes are throttled rather than
    // purely debounced so dragging tracks the monitors instead of jumping once
    // at the end.

    property int pending: -1

    property Timer throttle: Timer {
        interval: 220
        repeat: false
        onTriggered: sys.flush()
    }

    property Timer settle: Timer {
        interval: 600
        repeat: false
        onTriggered: {
            sys.holding = false
            sys.read()
        }
    }

    function set(target) {
        var clamped = Math.max(0, Math.min(100, Math.round(target)))
        sys.value = clamped
        sys.holding = true
        sys.pending = clamped
        settle.restart()

        if (!throttle.running)
            flush()
        else
            throttle.restart()
    }

    function flush() {
        if (sys.pending < 0 || !utillPath)
            return
        setProc.command = sys.command(["--ddcsetall", sys.pending])
        setProc.running = true
        sys.pending = -1
        throttle.restart()
    }
}
