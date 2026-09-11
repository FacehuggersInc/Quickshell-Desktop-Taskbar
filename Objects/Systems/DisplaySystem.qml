pragma Singleton

import QtQuick

QtObject {
    id: sys

    // ## Layout ownership
    // hyprctl keyword applies instantly but does not survive a compositor
    // reload, because Hyprland reads monitors from its own config. Rather than
    // generating code into a Lua file that is hand edited, the shell keeps the
    // layout under displays.layout and re-applies it at startup.

    property bool applying: false

    // ## Config access
    // A singleton is created outside the component tree, so the ShellRoot id
    // does not resolve here. shell.qml assigns settings and listens for saves.

    property var settings: null
    signal saveRequested()

    function stored() {
        if (!sys.settings)
            return ({})
        var cfg = sys.settings.displays
        return (cfg && cfg.layout) ? cfg.layout : ({})
    }

    function entryFor(name) {
        var all = sys.stored()
        return all[name] !== undefined ? all[name] : null
    }

    function save(name, entry) {
        if (!sys.settings)
            return
        if (!sys.settings.displays)
            sys.settings.displays = ({})
        if (!sys.settings.displays.layout)
            sys.settings.displays.layout = ({})
        sys.settings.displays.layout[name] = entry
        sys.saveRequested()
    }

    function forget(name) {
        if (!sys.settings || !sys.settings.displays || !sys.settings.displays.layout)
            return
        delete sys.settings.displays.layout[name]
        sys.saveRequested()
    }

    function modeString(entry) {
        if (entry.enabled === false)
            return "disable"
        if (!entry.width || !entry.height)
            return "preferred"
        var mode = entry.width + "x" + entry.height
        if (entry.refresh)
            mode += "@" + entry.refresh
        return mode
    }

    function apply(name, entry) {
        if (entry.enabled === false) {
            HyprlandSystem.disableMonitor(name)
            return
        }
        HyprlandSystem.applyMonitor(
            name,
            sys.modeString(entry),
            (entry.x || 0) + "x" + (entry.y || 0),
            entry.scale ? entry.scale : 1,
            entry.transform ? entry.transform : 0)
    }

    // A monitor described in the lua config is written there. Anything else
    // falls back to the shell's own store, which is re-applied at startup.
    function applyAndSave(name, entry) {
        if (sys.inLua(name))
            sys.writeRequested(name, sys.updatesFrom(entry))
        else
            sys.save(name, entry)

        sys.apply(name, entry)
    }

    // Promotes a monitor the shell was tracking into the lua config
    function adoptIntoLua(name, entry) {
        sys.writeRequested(name, sys.updatesFrom(entry))
        sys.forget(name)
    }

    // Only monitors the shell owns need this — lua ones are applied by Hyprland
    function applyAll() {
        if (sys.applying)
            return
        sys.applying = true

        var all = sys.stored()
        var mons = HyprlandSystem.monitors
        for (var i = 0; i < mons.length; i++) {
            var entry = all[mons[i].name]
            if (entry)
                sys.apply(mons[i].name, entry)
        }

        releaseTimer.restart()
    }

    property Timer releaseTimer: Timer {
        interval: 1200
        onTriggered: sys.applying = false
    }

    // ## Modes
    // Hyprland reports availableModes as "1920x1080@144.00Hz" strings

    function parseMode(text) {
        var at = text.indexOf("@")
        var size = at === -1 ? text : text.substring(0, at)
        var hz = at === -1 ? 0 : parseFloat(text.substring(at + 1).replace("Hz", ""))
        var parts = size.split("x")
        return {
            width: parseInt(parts[0]),
            height: parseInt(parts[1]),
            refresh: Math.round(hz * 100) / 100
        }
    }

    function resolutionsFor(monitor) {
        var seen = []
        var out = []
        var modes = monitor.availableModes || []
        for (var i = 0; i < modes.length; i++) {
            var m = sys.parseMode(modes[i])
            var key = m.width + "x" + m.height
            if (seen.indexOf(key) !== -1)
                continue
            seen.push(key)
            out.push({ label: key, value: key })
        }
        if (out.length === 0 && monitor.nativeWidth > 0)
            out.push({
                label: monitor.nativeWidth + "x" + monitor.nativeHeight,
                value: monitor.nativeWidth + "x" + monitor.nativeHeight
            })
        return out
    }

    function refreshRatesFor(monitor, resolution) {
        var out = []
        var seen = []
        var modes = monitor.availableModes || []
        for (var i = 0; i < modes.length; i++) {
            var m = sys.parseMode(modes[i])
            if (m.width + "x" + m.height !== resolution)
                continue
            if (seen.indexOf(m.refresh) !== -1)
                continue
            seen.push(m.refresh)
            out.push({ label: m.refresh + " Hz", value: m.refresh })
        }
        out.sort(function(a, b) { return b.value - a.value })
        if (out.length === 0 && monitor.refresh > 0)
            out.push({ label: monitor.refresh + " Hz", value: monitor.refresh })
        return out
    }

    // ## Hyprland's own lua config
    // A monitor with an hl.monitor rule is owned by that rule — edits are
    // written back into it rather than kept in the shell's own store, so there
    // is nothing for the two to disagree about after a reload.

    property var configLines: []
    property bool configScanned: false

    signal writeRequested(string output, var updates)

    function configFor(name) {
        for (var i = 0; i < sys.configLines.length; i++) {
            if (sys.configLines[i].output === name)
                return sys.configLines[i]
        }
        return null
    }

    function inLua(name) {
        return sys.configFor(name) !== null
    }

    function luaFieldsFor(name) {
        var entry = sys.configFor(name)
        return entry ? entry.fields : ({})
    }

    function updatesFrom(entry) {
        var out = {
            "mode": sys.modeString(entry),
            "position": (entry.x || 0) + "x" + (entry.y || 0),
            "scale": Number(entry.scale ? entry.scale : 1).toFixed(2)
        }
        if (entry.transform !== undefined && entry.transform !== null)
            out["transform"] = entry.transform
        return out
    }

    readonly property var transforms: [
        { label: "Normal", value: 0 },
        { label: "90°", value: 1 },
        { label: "180°", value: 2 },
        { label: "270°", value: 3 },
        { label: "Flipped", value: 4 },
        { label: "Flipped 90°", value: 5 },
        { label: "Flipped 180°", value: 6 },
        { label: "Flipped 270°", value: 7 }
    ]

    readonly property var scales: [
        { label: "100%", value: 1 },
        { label: "112.5%", value: 1.125 },
        { label: "125%", value: 1.25 },
        { label: "150%", value: 1.5 },
        { label: "175%", value: 1.75 },
        { label: "200%", value: 2 }
    ]
}
