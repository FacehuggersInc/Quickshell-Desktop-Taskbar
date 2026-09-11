pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: sys

    // ## State
    // Snapshots rebuilt off the event socket. Nothing here polls.

    property var monitors: []
    property var workspaces: []
    property var windows: []
    property var windowsByAddress: ({})

    property string focusedMonitor: ""
    property int focusedWorkspaceId: -1
    property string activeAddress: ""

    property bool ready: false

    signal changed()

    // ## Refresh
    // lastIpcObject only updates when the object is fetched again, so geometry
    // needs an explicit refresh before a snapshot is worth taking. Events are
    // coalesced first — a single workspace switch emits several.

    property Timer refreshTimer: Timer {
        interval: 60
        repeat: false
        onTriggered: {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            sys.settleTimer.restart()
        }
    }

    property Timer settleTimer: Timer {
        interval: 90
        repeat: false
        onTriggered: sys.rebuild()
    }

    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            sys.refreshTimer.restart()
        }
    }

    // Some actions invalidate state without emitting an event
    function refresh() {
        refreshTimer.restart()
    }

    function rebuild() {
        var mons = []
        var monModel = Hyprland.monitors ? Hyprland.monitors.values : []
        for (var i = 0; i < monModel.length; i++) {
            var m = monModel[i]
            var raw = m.lastIpcObject || {}
            var scale = raw.scale || 1

            // monitors reports the physical mode, clients reports logical
            // coordinates. Without dividing by scale, windows are drawn into a
            // coordinate space larger than the one they actually live in and
            // never reach the edges of the tile.
            var w = Math.round((raw.width || m.width || 0) / scale)
            var h = Math.round((raw.height || m.height || 0) / scale)
            var transform = raw.transform || 0
            if (transform === 1 || transform === 3 || transform === 5 || transform === 7) {
                var swap = w
                w = h
                h = swap
            }
            mons.push({
                name: m.name || raw.name || "",
                x: m.x || raw.x || 0,
                y: m.y || raw.y || 0,
                w: w,
                h: h,
                scale: scale,
                reservedTop: (raw.reserved && raw.reserved.length > 1) ? raw.reserved[1] : 0,
                transform: transform,
                vertical: h > w,
                focused: m.focused === true,
                activeWorkspaceId: m.activeWorkspace ? m.activeWorkspace.id : -1,
                activeWorkspaceName: m.activeWorkspace ? m.activeWorkspace.name : "",

                // A peeked bucket sits on top of the real workspace rather than
                // replacing it, and nothing else reports that it is showing
                specialWorkspace: (raw.specialWorkspace && raw.specialWorkspace.name)
                    ? raw.specialWorkspace.name.replace("special:", "") : "",

                // ## Hardware
                // Everything the display editor needs. availableModes is a list
                // of "1920x1080@144.00Hz" strings straight from Hyprland.
                description: raw.description || "",
                make: raw.make || "",
                model: raw.model || "",
                serial: raw.serial || "",
                refresh: raw.refreshRate ? Math.round(raw.refreshRate * 100) / 100 : 0,
                nativeWidth: raw.width || 0,
                nativeHeight: raw.height || 0,
                availableModes: raw.availableModes || [],
                disabled: raw.disabled === true,
                dpmsStatus: raw.dpmsStatus !== false,
                vrr: raw.vrr === true
            })
        }
        mons.sort(function(a, b) { return a.x - b.x })

        var spaces = []
        var wsModel = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var j = 0; j < wsModel.length; j++) {
            var ws = wsModel[j]
            var wsRaw = ws.lastIpcObject || {}
            var name = ws.name || wsRaw.name || ""
            spaces.push({
                id: ws.id,
                name: name,
                special: name.indexOf("special:") === 0,
                monitor: ws.monitor ? ws.monitor.name : (wsRaw.monitor || ""),
                windowCount: wsRaw.windows !== undefined ? wsRaw.windows : 0,
                focused: ws.focused === true
            })
        }

        var wins = []
        var byAddress = ({})
        var active = ""
        var topModel = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (var k = 0; k < topModel.length; k++) {
            var t = topModel[k]
            var tRaw = t.lastIpcObject || {}
            if (!t.address)
                continue

            var at = tRaw.at || [0, 0]
            var size = tRaw.size || [0, 0]
            var wsName = t.workspace ? t.workspace.name : (tRaw.workspace ? tRaw.workspace.name : "")

            var entry = {
                address: sys.normalizeAddress(t.address),
                pid: tRaw.pid || 0,
                appClass: tRaw["class"] || tRaw.initialClass || "",
                initialClass: tRaw.initialClass || "",
                title: t.title || tRaw.title || "",
                monitor: t.monitor ? t.monitor.name : "",
                workspaceId: t.workspace ? t.workspace.id : (tRaw.workspace ? tRaw.workspace.id : -1),
                workspaceName: wsName,
                special: wsName.indexOf("special:") === 0,
                x: at[0],
                y: at[1],
                w: size[0],
                h: size[1],
                floating: tRaw.floating === true,
                fullscreen: tRaw.fullscreen > 0,
                hidden: tRaw.hidden === true,
                activated: t.activated === true,

                // Capture handle for previews. Null until the address is
                // reported, and stale once the toplevel goes away, so consumers
                // must null check it.
                wayland: t.wayland || null
            }
            if (entry.activated)
                active = entry.address

            wins.push(entry)
            byAddress[entry.address] = entry
        }

        sys.monitors = mons
        sys.workspaces = spaces
        sys.windows = wins
        sys.windowsByAddress = byAddress
        sys.activeAddress = active

        var fm = Hyprland.focusedMonitor
        sys.focusedMonitor = fm ? fm.name : ""
        var fw = Hyprland.focusedWorkspace
        sys.focusedWorkspaceId = fw ? fw.id : -1

        sys.ready = true
        sys.changed()
    }

    // ## Lookups

    function monitorNames() {
        var out = []
        for (var i = 0; i < monitors.length; i++)
            out.push(monitors[i].name)
        return out
    }

    function monitorByName(name) {
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].name === name)
                return monitors[i]
        }
        return null
    }

    function windowsOnWorkspace(id) {
        var out = []
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].workspaceId === id)
                out.push(windows[i])
        }
        return out
    }

    function windowsOnMonitor(name) {
        var mon = monitorByName(name)
        if (!mon)
            return []
        return windowsOnWorkspace(mon.activeWorkspaceId)
    }

    function windowsInClass(appClass) {
        var out = []
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].appClass === appClass)
                out.push(windows[i])
        }
        return out
    }

    function windowsOnSpecial(bucket) {
        var target = "special:" + bucket
        var out = []
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].workspaceName === target)
                out.push(windows[i])
        }
        return out
    }

    // Which monitor a bucket is currently overlaid on, if any
    function monitorShowing(bucket) {
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].specialWorkspace === bucket)
                return monitors[i].name
        }
        return ""
    }

    function anySpecialShowing() {
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].specialWorkspace !== "")
                return monitors[i].specialWorkspace
        }
        return ""
    }

    function specialWorkspaces() {
        var out = []
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].special)
                out.push(workspaces[i])
        }
        return out
    }

    // ## Dispatch
    // Every function targets a window by address. A pid cannot distinguish
    // between windows of the same application.
    //
    // Since 0.55 Hyprland's config can be Lua, and in that mode hl.dispatch
    // takes a dispatcher table from hl.dsp rather than a legacy command string.
    // Quickshell reports which mode is live, so both forms are built here.

    // Hyprland.usingLua only exists in newer Quickshell builds and reads back as
    // undefined otherwise, so the config provider is probed directly and the
    // property is used only when it is a real boolean.
    property int luaProbed: -1

    readonly property bool lua: {
        if (typeof Hyprland.usingLua === "boolean")
            return Hyprland.usingLua
        return sys.luaProbed === 1
    }

    property Process luaProbe: Process {
        command: ["hyprctl", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text || ""
                var idx = text.indexOf("configProvider:")
                if (idx === -1) {
                    sys.luaProbed = 0
                    return
                }
                var line = text.substring(idx).split("\n")[0]
                sys.luaProbed = line.indexOf("lua") !== -1 ? 1 : 0
                console.log("HyprlandSystem config provider ->" + line.substring(15))
            }
        }
    }

    // Quickshell reports the address without the 0x prefix, but every Hyprland
    // selector expects it
    function normalizeAddress(address) {
        if (!address)
            return ""
        var a = String(address)
        return a.indexOf("0x") === 0 ? a : "0x" + a
    }

    function luaStr(value) {
        return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }

    function windowSelector(address) {
        return "address:" + normalizeAddress(address)
    }

    property bool debugDispatch: true

    function dispatch(request) {
        if (debugDispatch)
            console.log("HyprlandSystem dispatch (lua=" + sys.lua + ") -> " + request)
        Hyprland.dispatch(request)
        refresh()
    }

    function focusWindow(address) {
        if (lua)
            dispatch("hl.dsp.focus({window=" + luaStr(windowSelector(address)) + "})")
        else
            dispatch("focuswindow " + windowSelector(address))
    }

    function closeWindow(address) {
        if (lua)
            dispatch("hl.dsp.window.close({window=" + luaStr(windowSelector(address)) + "})")
        else
            dispatch("closewindow " + windowSelector(address))
    }

    function moveWindowToWorkspace(address, workspace, follow) {
        if (lua) {
            dispatch("hl.dsp.window.move({workspace=" + luaStr(workspace)
                     + ", follow=" + (follow ? "true" : "false")
                     + ", window=" + luaStr(windowSelector(address)) + "})")
        } else {
            var verb = follow ? "movetoworkspace" : "movetoworkspacesilent"
            dispatch(verb + " " + workspace + "," + windowSelector(address))
        }
    }

    function moveWindowToMonitor(address, monitorName) {
        var mon = monitorByName(monitorName)
        if (!mon)
            return
        moveWindowToWorkspace(address, mon.activeWorkspaceId, false)
    }

    // ## Runtime configuration
    // Under a lua config hyprctl rejects keyword outright — "keyword can't work
    // with non-legacy parsers, use eval" — so config changes go through
    // hyprctl eval with a lua expression. Legacy configs still take keyword.
    //
    // Neither survives a compositor reload, which is why the shell stores the
    // display layout and re-applies it at startup.

    property var configQueue: []

    property Process configProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                var reply = this.text.trim()
                if (reply && reply.toLowerCase() !== "ok")
                    console.log("HyprlandSystem config -> " + reply)
                sys.drainConfig()
            }
        }
    }

    function evaluate(expression) {
        sys.configQueue.push(["eval", expression])
        sys.drainConfig()
    }

    function keyword(name, value) {
        if (sys.lua)
            return
        sys.configQueue.push(["keyword", name, value])
        sys.drainConfig()
    }

    function drainConfig() {
        if (configProc.running || sys.configQueue.length === 0)
            return
        var next = sys.configQueue.shift()
        configProc.command = next[0] === "eval"
            ? ["hyprctl", "eval", next[1]]
            : ["hyprctl", "keyword", next[1], next[2]]
        configProc.running = true
        refresh()
    }

    function setOption(path, value, luaValue) {
        if (sys.lua)
            evaluate('hl.config({["' + path + '"] = ' + luaValue + '})')
        else
            keyword(path, value)
    }

    function applyMonitor(name, mode, position, scale, transform) {
        var rotation = (transform !== undefined && transform !== null) ? transform : 0

        if (sys.lua) {
            evaluate('hl.monitor({output=' + luaStr(name)
                     + ', mode=' + luaStr(mode)
                     + ', position=' + luaStr(position)
                     + ', scale=' + scale
                     + ', transform=' + rotation + '})')
            return
        }

        var spec = name + "," + mode + "," + position + "," + scale
        if (rotation !== 0)
            spec += ",transform," + rotation
        keyword("monitor", spec)
    }

    function disableMonitor(name) {
        if (sys.lua) {
            evaluate('hl.monitor({output=' + luaStr(name) + ', disabled=true})')
            return
        }
        keyword("monitor", name + ",disable")
    }

    function switchWorkspace(id) {
        if (lua)
            dispatch("hl.dsp.focus({workspace=" + luaStr(id) + "})")
        else
            dispatch("workspace " + id)
    }

    function toggleSpecial(name) {
        if (lua)
            dispatch("hl.dsp.workspace.toggle_special(" + luaStr(name) + ")")
        else
            dispatch("togglespecialworkspace " + name)
    }

    function stashWindow(address, bucket) {
        moveWindowToWorkspace(address, "special:" + bucket, false)
    }

    // The two below are only reached from the workspace overlay. Their Lua forms
    // follow the hl.dsp namespace pattern but are not confirmed against a
    // running 0.55 the way the ones above are.

    function swapActiveWorkspaces(monitorA, monitorB) {
        if (lua) {
            dispatch("hl.dsp.workspace.swap_active({monitor_a=" + luaStr(monitorA)
                     + ", monitor_b=" + luaStr(monitorB) + "})")
        } else {
            dispatch("swapactiveworkspaces " + monitorA + " " + monitorB)
        }
    }

    function moveWorkspaceToMonitor(workspace, monitorName) {
        if (lua) {
            dispatch("hl.dsp.workspace.move_to_monitor({workspace=" + luaStr(workspace)
                     + ", monitor=" + luaStr(monitorName) + "})")
        } else {
            dispatch("moveworkspacetomonitor " + workspace + " " + monitorName)
        }
    }

    Component.onCompleted: {
        rebuild()
    }
}
