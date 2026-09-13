//@ pragma UseQApplication
//@ pragma IconTheme material-symbols

import QtQuick
import Quickshell
import Quickshell.Io

import Quickshell.Services.Notifications

import qs.Objects.Window
import qs.Objects.Window.WorkspaceOverview
import qs.Objects.Systems
import qs.Objects.Theme
import qs.Objects.Design

import Quickshell.Hyprland

ShellRoot {
    // INIT
    id: root

    FileView {
        id: configFile
        preload: true
        blockLoading: true
        path: Qt.resolvedUrl("./config.json")
        watchChanges: true
        onFileChanged: this.reload()
        onAdapterUpdated: this.writeAdapter()
    }
    // A parse failure used to take the whole shell down to defaults with no
    // indication why. This reports it and marks the config unhealthy so nothing
    // gets written back over a file we could not read.
    //
    // Nothing read by this binding may also be written by it — an earlier
    // version cached the last good copy in a property it also read here, and
    // QML broke the cycle by disabling the binding, which emptied every page
    // that builds from config.

    property bool configValid: true

    // config.json parses to a plain object, so mutating a nested value registers
    // no dependency and bindings that read it never re-evaluate. Anything that
    // needs to react to a settings write reads this counter as well.
    property int settingsRevision: 0

    property var settings: {
        var raw = configFile.text()
        try {
            var parsed = JSON.parse(raw)
            if (parsed && typeof parsed === "object") {
                root.configValid = true
                return parsed
            }
            console.log("config.json did not parse to an object")
        } catch (e) {
            console.log("config.json is not valid JSON: " + e)
        }
        root.configValid = false
        return ({})
    }

    property var utill: {
        var interpreter = (settings.utill && settings.utill.interpreter)
            ? settings.utill.interpreter : "python3"
        var script = (settings.utill && settings.utill.path)
            ? settings.utill.path
            : Qt.resolvedUrl("./Scripts/utill.py").toString().replace("file://", "")
        return [interpreter, script]
    }
    // ## Theme
    // Colour lives in the Theme singleton. config.json holds only what the user
    // authored — mode source, accent source, accent, glass on/off, scrim
    // strength. Everything else is derived and never written back.

    readonly property var themeConfig: {
        var bump = root.settingsRevision
        return settings.theme || ({})
    }
    readonly property var theme: Theme.legacy

    property bool darkMode: true

    function evalDarkMode(){
        if (settings.forceDarkMode) {
            root.darkMode = true
            return
        }
        var explicit = root.themeConfig.mode
        if (explicit === "dark") { root.darkMode = true; return }
        if (explicit === "light") { root.darkMode = false; return }

        if (root.wallpaperMode === 1) { root.darkMode = false; return }
        if (root.wallpaperMode === 2) { root.darkMode = true; return }

        var hours = (settings.wallpapers && settings.wallpapers.darkModeHours)
            ? settings.wallpapers.darkModeHours : { at: 21, before: 6 }
        var hour = new Date().getHours()
        root.darkMode = (hour >= hours.at || hour < hours.before)
    }

    // Seed picked from the wallpaper quantizer: most saturated colour that is
    // not already near black or white. Theme clamps it after this.
    readonly property color accentSeed: {
        var cols = colorQuan.colors
        if (!cols || cols.length === 0)
            return Theme.accentFixed
        var best = cols[0]
        var bestScore = -1
        for (var i = 0; i < cols.length; i++) {
            var c = cols[i]
            var score = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.2)
            if (score > bestScore) {
                bestScore = score
                best = c
            }
        }
        return best
    }

    // Monitor settings do not survive a compositor reload, so the stored layout
    // is re-applied once the event socket has reported what is connected
    Binding { target: DisplaySystem; property: "settings"; value: root.settings }

    Binding {
        target: ClockSystem
        property: "use24"
        value: {
            var bump = root.settingsRevision
            var widgets = root.settings.widgets || ({})
            return widgets.clock24 === true
        }
    }

    Connections {
        target: DisplaySystem
        function onSaveRequested() { root.saveSettings() }
    }

    // ## Hyprland lua config
    // Only .lua is read now. The .conf form is not scanned — this shell writes
    // lua, and showing both invited edits landing in a file Hyprland ignores.

    Process {
        id: luaMonitorsProc
        command: root.newUtill(["--luamonitors"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                var out = []
                if (text && text !== "none") {
                    var entries = text.split("\u001e")
                    for (var i = 0; i < entries.length; i++) {
                        var parts = entries[i].split("\u001f")
                        if (parts.length < 4) continue

                        var fields = ({})
                        var pairs = parts[3].split(";")
                        for (var j = 0; j < pairs.length; j++) {
                            var kv = pairs[j].split("=")
                            if (kv.length >= 2)
                                fields[kv[0]] = kv.slice(1).join("=")
                        }

                        out.push({
                            file: parts[0],
                            line: parseInt(parts[1]),
                            output: parts[2],
                            fields: fields
                        })
                    }
                }
                DisplaySystem.configLines = out
                DisplaySystem.configScanned = true
            }
        }
    }

    Process {
        id: luaWriteProc
        stdout: StdioCollector {
            onStreamFinished: {
                var reply = this.text.trim()
                if (reply.indexOf("ok:") === 0) {
                    console.log("hyprland.lua updated, backup at " + reply.substring(3))
                    luaMonitorsProc.running = true
                } else {
                    console.log("hyprland.lua not written: " + reply)
                    root.notify("Display Settings",
                                "Could not write to your Hyprland config.\n" + reply,
                                "brightness")
                }
            }
        }
    }

    Connections {
        target: DisplaySystem
        function onWriteRequested(output, updates) {
            if (luaWriteProc.running)
                return
            var args = ["--luawritemonitor", output]
            for (var key in updates)
                args.push(key + "=" + updates[key])
            luaWriteProc.command = root.newUtill(args)
            luaWriteProc.running = true
        }
    }

    // ## Hotkeys
    // Same surgical-write model as monitors: read what is there, replace only
    // the call being edited, back up first.

    Process {
        id: luaBindsProc
        command: root.newUtill(["--luabinds"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                var out = []
                if (text && text !== "none") {
                    var entries = text.split("\u001e")
                    for (var i = 0; i < entries.length; i++) {
                        var parts = entries[i].split("\u001f")
                        if (parts.length < 6) continue
                        out.push({
                            file: parts[0],
                            line: parseInt(parts[1]),
                            key: parts[2],
                            kind: parts[3],
                            detail: parts[4],
                            action: parts[5],
                            options: parts.length > 6 ? parts[6] : ""
                        })
                    }
                }
                HotkeySystem.binds = out
                HotkeySystem.scanned = true
            }
        }
    }

    Process {
        id: luaConstsProc
        command: root.newUtill(["--luaconsts"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 2) continue
                        out.push({ name: parts[0], value: parts[1] })
                    }
                }
                HotkeySystem.consts = out
            }
        }
    }

    Process {
        id: luaBindWriteProc
        stdout: StdioCollector {
            onStreamFinished: {
                var reply = this.text.trim()
                if (reply.indexOf("ok:") === 0) {
                    luaBindsProc.running = true
                } else {
                    console.log("hyprland.lua bind not written: " + reply)
                    root.notify("Hotkeys",
                                "Could not write to your Hyprland config.\n" + reply,
                                "settings")
                }
            }
        }
    }

    function runBindWrite(args) {
        if (luaBindWriteProc.running)
            return
        luaBindWriteProc.command = root.newUtill(args)
        luaBindWriteProc.running = true
    }

    Connections {
        target: HotkeySystem

        function onReadRequested() {
            if (!luaBindsProc.running) luaBindsProc.running = true
        }

        function onAddRequested(key, command) {
            root.runBindWrite(["--luaaddbind", key,
                               HotkeySystem.execExpression(command)])
        }

        function onUpdateRequested(file, line, key, command, options) {
            var args = ["--luawritebind", file, String(line), key,
                        HotkeySystem.execExpression(command)]
            if (options && options !== "")
                args.push(options)
            root.runBindWrite(args)
        }

        function onRemoveRequested(file, line) {
            root.runBindWrite(["--luadeletebind", file, String(line)])
        }
    }

    // ## Startup commands

    Process {
        id: luaStartupProc
        command: root.newUtill(["--luastartup"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                var out = []
                if (text && text !== "none") {
                    var entries = text.split("\u001e")
                    for (var i = 0; i < entries.length; i++) {
                        var parts = entries[i].split("\u001f")
                        if (parts.length < 3) continue
                        out.push({
                            file: parts[0],
                            line: parseInt(parts[1]),
                            command: parts[2]
                        })
                    }
                }
                StartupSystem.entries = out
                StartupSystem.scanned = true
            }
        }
    }

    Process {
        id: luaStartupWriteProc
        stdout: StdioCollector {
            onStreamFinished: {
                var reply = this.text.trim()
                if (reply.indexOf("ok:") === 0) {
                    luaStartupProc.running = true
                } else {
                    console.log("startup entry not written: " + reply)
                    root.notify("Startup Apps",
                                "Could not write to your Hyprland config.\n" + reply,
                                "settings")
                }
            }
        }
    }

    function runStartupWrite(args) {
        if (luaStartupWriteProc.running)
            return
        luaStartupWriteProc.command = root.newUtill(args)
        luaStartupWriteProc.running = true
    }

    Connections {
        target: StartupSystem

        function onReadRequested() {
            if (!luaStartupProc.running) luaStartupProc.running = true
        }

        function onAddRequested(command) {
            root.runStartupWrite(["--luaaddstartup", command])
        }

        function onUpdateRequested(file, line, command) {
            root.runStartupWrite(["--luawritestartup", file, String(line), command])
        }

        function onRemoveRequested(file, line) {
            root.runStartupWrite(["--luadeletestartup", file, String(line)])
        }
    }

    // ## Mime handlers

    Process {
        id: mimeReadProc
        command: root.newUtill(["--mimetypes"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                var out = []
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 1 || !parts[0]) continue
                        var candidates = (parts.length > 2 && parts[2] !== "")
                            ? parts[2].split(",") : []
                        out.push({
                            mime: parts[0],
                            current: parts.length > 1 ? parts[1] : "",
                            candidates: candidates,
                            extensions: parts.length > 3 ? parts[3] : "",
                            added: (parts.length > 4 && parts[4] !== "")
                                ? parts[4].split(",") : []
                        })
                    }
                }
                MimeSystem.entries = out
                MimeSystem.scanned = true
            }
        }
    }

    Process {
        id: mimeWriteProc
        stdout: StdioCollector {
            onStreamFinished: {
                var reply = this.text.trim()
                if (reply === "ok") {
                    mimeReadProc.running = true
                } else {
                    console.log("mimeapps.list not written: " + reply)
                    root.notify("File Associations",
                                "Could not update mimeapps.list.\n" + reply,
                                "settings")
                }
            }
        }
    }

    Connections {
        target: MimeSystem

        function onReadRequested() {
            if (!mimeReadProc.running) mimeReadProc.running = true
        }

        function onSetRequested(mime, desktopId, claim) {
            if (mimeWriteProc.running) return
            var args = ["--mimeset", mime, desktopId]
            if (claim) args.push("claim")
            mimeWriteProc.command = root.newUtill(args)
            mimeWriteProc.running = true
        }

        function onClearRequested(mime, unclaim) {
            if (mimeWriteProc.running) return
            var args = ["--mimeclear", mime]
            if (unclaim) args.push("unclaim")
            mimeWriteProc.command = root.newUtill(args)
            mimeWriteProc.running = true
        }
    }

    // ## Network

    Process {
        id: netDevicesProc
        command: root.newUtill(["--netdevices"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 4) continue
                        out.push({
                            device: parts[0], type: parts[1],
                            state: parts[2], connection: parts[3]
                        })
                    }
                }
                NetworkSystem.devices = out
                netConnectionsProc.running = true
            }
        }
    }

    Process {
        id: netConnectionsProc
        command: root.newUtill(["--netconnections"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 5) continue
                        out.push({
                            name: parts[0], uuid: parts[1], type: parts[2],
                            device: parts[3], active: parts[4] === "yes"
                        })
                    }
                }
                NetworkSystem.connections = out
                netRadioProc.running = true
            }
        }
    }

    Process {
        id: netRadioProc
        command: root.newUtill(["--netradio"])
        stdout: StdioCollector {
            onStreamFinished: {
                NetworkSystem.wifiRadio = this.text.trim()
                netWifiProc.running = true
            }
        }
    }

    Process {
        id: netWifiProc
        command: root.newUtill(["--netwifi"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 4) continue
                        out.push({
                            active: parts[0] === "yes", ssid: parts[1],
                            signal: parts[2], security: parts[3]
                        })
                    }
                    out.sort(function(a, b) {
                        return parseInt(b.signal) - parseInt(a.signal)
                    })
                }
                NetworkSystem.networks = out
                NetworkSystem.scanned = true
                NetworkSystem.busy = false
            }
        }
    }

    Process {
        id: netActionProc
        stdout: StdioCollector {
            onStreamFinished: {
                var reply = this.text.trim()
                NetworkSystem.busy = false
                if (reply.indexOf("error:") === 0) {
                    NetworkSystem.lastError = reply.substring(6)
                    root.notify("Network", NetworkSystem.lastError, "wired")
                } else {
                    NetworkSystem.lastError = ""
                }
                netDevicesProc.running = true
            }
        }
    }

    function runNetAction(args) {
        if (netActionProc.running)
            return
        NetworkSystem.busy = true
        netActionProc.command = root.newUtill(args)
        netActionProc.running = true
    }

    Connections {
        target: NetworkSystem

        function onReadRequested() {
            if (!netDevicesProc.running) netDevicesProc.running = true
        }

        function onScanRequested() {
            NetworkSystem.busy = true
            root.runNetAction(["--netwifiscan"])
        }

        function onRadioRequested(state) {
            root.runNetAction(["--netradio", state])
        }

        function onConnectRequested(kind, target, secret) {
            if (kind === "wifi")
                root.runNetAction(["--netconnect", "wifi", target, secret])
            else
                root.runNetAction(["--netconnect", target])
        }

        function onDisconnectRequested(target) {
            root.runNetAction(["--netdisconnect", target])
        }

        function onForgetRequested(target) {
            root.runNetAction(["--netforget", target])
        }
    }

    // ## Packages

    Process {
        id: pkgListProc
        command: root.newUtill(["--pkglist"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 2) continue
                        out.push({
                            source: parts[0],
                            name: parts[1],
                            version: parts.length > 2 ? parts[2] : "",
                            installed: parts.length > 3 ? parts[3] : "",
                            description: parts.length > 4 ? parts[4] : "",
                            depends: parts.length > 5 ? parts[5] : "",
                            size: parts.length > 6 ? parts[6] : ""
                        })
                    }
                }
                PackageSystem.packages = out
                PackageSystem.scanned = true
                pkgHelperProc.running = true
            }
        }
    }

    Process {
        id: pkgHelperProc
        command: root.newUtill(["--pkghelper"])
        stdout: StdioCollector {
            onStreamFinished: PackageSystem.helper = this.text.trim()
        }
    }

    Process {
        id: pkgUpdatesProc
        command: root.newUtill(["--pkgupdates"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 2) continue
                        out.push({
                            source: parts[0],
                            name: parts[1],
                            current: parts.length > 2 ? parts[2] : "",
                            next: parts.length > 3 ? parts[3] : ""
                        })
                    }
                }
                PackageSystem.updates = out
                PackageSystem.busy = false
            }
        }
    }

    // Handed to a terminal so the command is visible and confirmed. The shell
    // never runs a privileged package command itself.
    function runInTerminal(command, title) {
        // ## Holding the window open
        // Ghostty's -e closes the surface the moment the command exits, and
        // does not hand the child an interactive stdin — a read in the command
        // gets EOF immediately, so no epilogue written here can hold it. Its
        // own --wait-after-command flag is the only thing that does, so it is
        // added when missing. Other terminals are left alone and rely on the
        // read below.
        var wrapped = "{ " + command + " ; }; status=$?"
            + "; exec 0</dev/tty 2>/dev/null || true"
            + "; read -r -t 0.2 -n 10000 _discard 2>/dev/null || true"
            + "; printf '\\n--- finished with status %s ---\\npress enter to close ' \"$status\""
            + "; read -r _close </dev/tty 2>/dev/null || sleep 30"

        // ## Building the invocation
        // cmd() wraps anything containing shell syntax in bash -c, which turned
        // "ghostty -e bash -c" into argv[2] and left our payload as $0 — the
        // window never even opened. The line is assembled as one shell string
        // instead, then run through bash once.

        var commands = root.settings.commands || ({})
        var custom = commands.terminal_run || ""
        var line = ""

        if (custom) {
            line = custom.indexOf("{command}") !== -1
                ? custom.replace("{command}", root.shellQuote(wrapped))
                : custom + " " + root.shellQuote(wrapped)
        } else if (commands.terminal) {
            line = commands.terminal + " -e bash -c " + root.shellQuote(wrapped)
        } else {
            root.notify("Packages", "No terminal command configured.", "terminal")
            return
        }

        root.execute(["bash", "-c", root.holdTerminal(line)])
    }

    // Single quoted, with embedded quotes escaped the only way bash allows
    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'"
    }

    // Ghostty needs its own flag to survive the command finishing. Operates on
    // the command line rather than argv, since the terminal may be buried
    // inside a shell string by then.
    function holdTerminal(line) {
        var text = String(line)
        if (text.indexOf("ghostty") === -1)
            return text
        if (text.indexOf("--wait-after-command") !== -1)
            return text
        return text.replace("ghostty", "ghostty --wait-after-command=true")
    }

    Connections {
        target: PackageSystem

        function onReadRequested() {
            if (!pkgListProc.running) pkgListProc.running = true
        }

        function onUpdatesRequested() {
            if (pkgUpdatesProc.running) return
            PackageSystem.busy = true
            pkgUpdatesProc.running = true
        }

        function onTerminalRequested(command, title) {
            root.runInTerminal(command, title)
        }
    }

    // ## Calendar

    Process {
        id: calReadProc
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 5) continue
                        out.push({
                            id: parts[0],
                            date: parts[1],
                            time: parts[2],
                            endTime: parts[3],
                            title: parts[4],
                            notes: parts.length > 5 ? parts[5] : "",
                            location: parts.length > 6 ? parts[6] : "",
                            source: parts.length > 7 ? parts[7] : "",
                            remind: parts.length > 8 ? parts[8] : "",
                            repeating: parts.length > 9 && parts[9] === "1"
                        })
                    }
                }
                CalendarSystem.events = out
                CalendarSystem.loaded = true
            }
        }
    }

    Process {
        id: calSubsProc
        command: root.newUtill(["--calsubs"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 3) continue
                        out.push({
                            key: parts[0],
                            name: parts[1],
                            url: parts[2],
                            enabled: parts.length > 3 && parts[3] === "1",
                            count: parts.length > 4 ? parseInt(parts[4]) : 0,
                            colour: parts.length > 5 ? parts[5] : ""
                        })
                    }
                }
                CalendarSystem.subscriptions = out
            }
        }
    }

    Process {
        id: calWriteProc
        stdout: StdioCollector {
            onStreamFinished: {
                var reply = this.text.trim()
                if (reply.indexOf("error:") === 0)
                    CalendarSystem.lastError = reply.substring(6)
                else
                    CalendarSystem.lastError = ""
                CalendarSystem.refresh()
                calSubsProc.running = true
            }
        }
    }

    Process {
        id: calSyncProc
        stdout: StdioCollector {
            onStreamFinished: {
                CalendarSystem.syncing = false

                // Each row is key, count, error — a feed that failed keeps
                // whatever it had rather than being emptied
                var failures = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length > 2 && parts[2] !== "")
                            failures.push(parts[0] + ": " + parts[2])
                    }
                }
                CalendarSystem.lastError = failures.join("   ")

                CalendarSystem.refresh()
                calSubsProc.running = true
            }
        }
    }

    function runCalWrite(args) {
        if (calWriteProc.running)
            return
        calWriteProc.command = root.newUtill(args)
        calWriteProc.running = true
    }

    Connections {
        target: CalendarSystem

        function onReadRequested(from, to) {
            if (calReadProc.running) return
            calReadProc.command = root.newUtill(["--calevents", from, to])
            calReadProc.running = true
        }

        function onAddRequested(fields) {
            root.runCalWrite(["--caladd", fields.title, fields.date,
                fields.time || "", fields.endTime || "", fields.notes || "",
                fields.remind || "", fields.repeat || "none"])
        }

        function onEditRequested(id, fields) {
            root.runCalWrite(["--caledit", id, fields.title, fields.date,
                fields.time || "", fields.endTime || "", fields.notes || "",
                fields.remind || "", fields.repeat || "none"])
        }

        function onDeleteRequested(id) {
            root.runCalWrite(["--caldelete", id])
        }

        function onSubsRequested() {
            if (!calSubsProc.running) calSubsProc.running = true
        }

        function onSubAddRequested(url, name) {
            root.runCalWrite(["--calsubadd", url, name])
        }

        function onSubColourRequested(key, colour) {
            root.runCalWrite(["--calsubcolour", key, colour])
        }

        function onSubRemoveRequested(key) {
            root.runCalWrite(["--calsubremove", key])
        }

        function onSyncRequested(key) {
            if (calSyncProc.running) return
            CalendarSystem.syncing = true
            calSyncProc.command = key && key !== ""
                ? root.newUtill(["--calsync", key])
                : root.newUtill(["--calsync"])
            calSyncProc.running = true
        }

        function onReminderDue(event) {
            var when = event.time && event.time !== "" ? " at " + event.time : ""
            root.notify("Calendar", event.title + when, "history")
        }
    }

    Timer {
        id: calendarStartup
        interval: 2500
        repeat: false
        running: true
        onTriggered: {
            CalendarSystem.refresh()
            CalendarSystem.subsRequested()
        }
    }

    // Feeds are refreshed on a slow cadence; nothing here is urgent
    Timer {
        interval: 1800000
        repeat: true
        running: true
        onTriggered: CalendarSystem.syncRequested("")
    }

    // ## Clock, alarms, timers and tracking

    Process {
        id: alarmsProc
        command: root.newUtill(["--alarms"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 3) continue
                        var days = []
                        if (parts[3] && parts[3] !== "") {
                            var pieces = parts[3].split(",")
                            for (var j = 0; j < pieces.length; j++)
                                days.push(parseInt(pieces[j]))
                        }
                        out.push({
                            id: parts[0], label: parts[1], time: parts[2],
                            days: days,
                            enabled: parts[4] === "1",
                            popup: parts[5] === "1"
                        })
                    }
                }
                ClockSystem.alarms = out
            }
        }
    }

    Process {
        id: timersProc
        command: root.newUtill(["--timers"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 3) continue
                        out.push({
                            id: parts[0], label: parts[1],
                            seconds: parseInt(parts[2]),
                            popup: parts[3] === "1"
                        })
                    }
                }
                ClockSystem.timers = out
            }
        }
    }

    Process {
        id: trackingProc
        command: root.newUtill(["--tracking"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 3) continue
                        out.push({
                            appClass: parts[0],
                            total: parseInt(parts[1]),
                            sessions: parseInt(parts[2]),
                            reminder: parts.length > 3 ? parts[3] : "",
                            popup: parts.length > 4 && parts[4] === "1",
                            lastSeen: parts.length > 5 ? parseInt(parts[5]) : 0
                        })
                    }
                }
                ClockSystem.tracking = out
            }
        }
    }

    Process {
        id: remindersProc
        command: root.newUtill(["--reminders"])
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var text = this.text.trim()
                if (text && text !== "none") {
                    var rows = text.split("\u001e")
                    for (var i = 0; i < rows.length; i++) {
                        var parts = rows[i].split("\u001f")
                        if (parts.length < 5) continue
                        out.push({
                            id: parts[0],
                            label: parts[1],
                            appClass: parts[2],
                            match: parts[3],
                            seconds: parseInt(parts[4]),
                            popup: parts[5] === "1",
                            auto: parts[6] === "1"
                        })
                    }
                }
                ClockSystem.reminders = out
            }
        }
    }

    Process {
        id: clockWriteProc
        stdout: StdioCollector {
            onStreamFinished: {
                alarmsProc.running = true
                timersProc.running = true
                remindersProc.running = true
            }
        }
    }

    // Ticks and session marks share one process, so several arriving together
    // used to be dropped by the busy guard — which is why applications showed
    // zero sessions while plainly open. They queue instead.
    property var trackQueue: []

    Process {
        id: trackTickProc
        stdout: StdioCollector {
            onStreamFinished: root.drainTrackQueue()
        }
    }

    function queueTrack(args) {
        var next = root.trackQueue.slice()
        next.push(args)
        root.trackQueue = next
        root.drainTrackQueue()
    }

    function drainTrackQueue() {
        if (trackTickProc.running || root.trackQueue.length === 0)
            return
        var next = root.trackQueue.slice()
        var args = next.shift()
        root.trackQueue = next
        trackTickProc.command = root.newUtill(args)
        trackTickProc.running = true
    }

    function runClockWrite(args) {
        if (clockWriteProc.running)
            return
        clockWriteProc.command = root.newUtill(args)
        clockWriteProc.running = true
    }

    Connections {
        target: ClockSystem

        function onReadRequested() {
            if (!alarmsProc.running) alarmsProc.running = true
            if (!timersProc.running) timersProc.running = true
            if (!trackingProc.running) trackingProc.running = true
            if (!remindersProc.running) remindersProc.running = true
        }

        function onReminderAddRequested(label, appClass, match, seconds, popup, auto) {
            root.runClockWrite(["--reminderadd", label, appClass, match,
                seconds, popup, auto])
        }

        function onReminderSetRequested(id, field, value) {
            root.runClockWrite(["--reminderset", id, field, value])
        }

        function onReminderDeleteRequested(id) {
            root.runClockWrite(["--reminderdelete", id])
        }

        function onAlarmAddRequested(label, time, days, popup) {
            root.runClockWrite(["--alarmadd", label, time, days, popup])
        }

        function onAlarmSetRequested(id, field, value) {
            root.runClockWrite(["--alarmset", id, field, value])
        }

        function onAlarmDeleteRequested(id) {
            root.runClockWrite(["--alarmdelete", id])
        }

        function onTimerAddRequested(label, seconds, popup) {
            root.runClockWrite(["--timeradd", label, seconds, popup])
        }

        function onTimerStartRequested(label, seconds, popup) {
            // Adding a timer starts it. Saving one that then sat there doing
            // nothing was the reason a timer "never went off".
            ClockSystem.startTimer("pending-" + Date.now(), label,
                parseInt(seconds), popup === "1")
        }

        function onTimerDeleteRequested(id) {
            root.runClockWrite(["--timerdelete", id])
        }

        function onTrackTick(step, classes) {
            root.queueTrack(["--tracktick", step].concat(classes))
        }

        function onTrackSession(appClass) {
            root.queueTrack(["--tracksession", appClass])
        }

        function onTrackSetRequested(appClass, minutes, popup) {
            root.runClockWrite(["--trackset", appClass, minutes, popup])
        }

        function onTrackResetRequested(appClass) {
            root.runClockWrite(["--trackreset", appClass])
        }
    }

    // Tracking totals are re-read on a slow cadence; nothing needs them sooner
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            if (!trackingProc.running) trackingProc.running = true
        }
    }

    Timer {
        interval: 3000
        repeat: false
        running: true
        onTriggered: ClockSystem.refresh()
    }

    Timer {
        id: displayRestoreTimer
        interval: 1500
        repeat: false
        onTriggered: DisplaySystem.applyAll()
    }

    Timer {
        id: darkModeTimer
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.evalDarkMode()
    }

    Binding { target: Theme; property: "darkMode"; value: root.darkMode }
    Binding { target: Theme; property: "accentSeed"; value: root.accentSeed }
    Binding { target: Theme; property: "fontFamily"; value: root.settings.fontFamily || "JetBrainsMono" }
    Binding {
        target: Theme
        property: "glass"
        value: root.themeConfig.glass !== undefined ? root.themeConfig.glass : true
    }
    Binding {
        target: IconMap
        property: "mode"
        value: root.themeConfig.icons || "auto"
    }
    Binding {
        target: IconMap
        property: "family"
        value: root.themeConfig.iconFamily || "Material Symbols Rounded"
    }
    Binding {
        target: Theme
        property: "previewMode"
        value: root.themeConfig.previews || "still"
    }
    Binding {
        target: Theme
        property: "panelDimStrength"
        value: root.themeConfig.panelDim !== undefined ? root.themeConfig.panelDim : 1.0
    }
    Binding {
        target: Theme
        property: "overlayDimStrength"
        value: root.themeConfig.overlayDim !== undefined ? root.themeConfig.overlayDim : 1.0
    }
    Binding {
        target: Theme
        property: "blurMode"
        value: root.themeConfig.blurMode || "protocol"
    }
    Binding {
        target: Theme
        property: "accentSource"
        value: root.themeConfig.accentSource || "fixed"
    }
    Binding {
        target: Theme
        property: "accentFixed"
        value: root.themeConfig.accent || root.themeConfig.primary || "#6b5d62"
    }
    Binding {
        target: Theme
        property: "scrimStrength"
        value: root.themeConfig.scrimStrength !== undefined ? root.themeConfig.scrimStrength : 1.0
    }

    property bool initialDarkHourCheck: false
    property var monitorResolutions: ({})  // name -> {w, h}
    property var ddcMap: ({})              // connector name -> DDC display number
    property var monitorInfos: []          // full monitor info sorted left-to-right

    // ## Monitors
    // Live from the Hyprland event socket. Nothing about which displays exist is
    // stored in config any more — a name is stable, an array index is not.

    readonly property var displayNames: {
        var out = []
        var mons = HyprlandSystem.monitors
        for (var i = 0; i < mons.length; i++)
            out.push(mons[i].name)
        return out
    }

    readonly property string primaryDisplay: {
        var configured = root.settings.primaryDisplay
        if (configured && root.displayNames.indexOf(configured) !== -1)
            return configured
        var focused = HyprlandSystem.focusedMonitor
        if (focused && root.displayNames.indexOf(focused) !== -1)
            return focused
        return root.displayNames.length > 0 ? root.displayNames[0] : ""
    }

    readonly property int primaryDisplayIndex: {
        var idx = root.displayNames.indexOf(root.primaryDisplay)
        return idx === -1 ? 0 : idx
    }

    function syncMonitors() {
        var mons = HyprlandSystem.monitors
        if (!mons || mons.length === 0)
            return

        var res = {}
        for (var i = 0; i < mons.length; i++)
            res[mons[i].name] = { w: mons[i].w, h: mons[i].h }

        root.monitorResolutions = res
        root.monitorInfos = mons
    }

    // One time move from the old positional scheme. displays was an array of
    // connector names and primaryDisplayIndex pointed into it, so both broke
    // whenever a monitor was unplugged or the order changed.
    function migrateDisplayConfig() {
        if (root.settings.primaryDisplay !== undefined)
            return

        var old = root.settings.displays
        var idx = root.settings.primaryDisplayIndex
        if (old && old.length > 0 && idx !== undefined && idx !== null
                && idx >= 0 && idx < old.length) {
            root.settings.primaryDisplay = old[idx]
        } else {
            root.settings.primaryDisplay = HyprlandSystem.focusedMonitor
        }

        delete root.settings.displays
        delete root.settings.primaryDisplayIndex
        root.saveSettings()
    }

    Connections {
        target: HyprlandSystem
        function onChanged() { root.syncMonitors() }
    }

    // Brightness reads once at startup rather than on every panel open
    Binding { target: BrightnessSystem; property: "utillInterpreter"; value: root.utill[0] }
    Binding { target: BrightnessSystem; property: "utillPath"; value: root.utill[1] }

    // ddcutil is not a Hyprland concern, so this one still shells out
    Process {
        id: ddcMappingProc
        command: root.newUtill(["--ddcmapping"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (!text || text === "none")
                    return
                var map = {}
                text.split("|").forEach(function(entry) {
                    var parts = entry.split(":")
                    if (parts.length >= 2) map[parts[0]] = parseInt(parts[1])
                })
                root.ddcMap = map
            }
        }
    }

    // Theater mode
    property bool theaterMode: false
    property var theaterPrevBrightness: []

    // Reads current brightness before dimming for theater mode restore
    Process {
        id: theaterBrightnessProc
        command: root.newUtill(["--ddcgetbrightness"])
        property int pendingDim: 10
        property int pendingPrimary: 0
        property string pendingWallpaper: ""
        stdout: StdioCollector {
            onStreamFinished: {
                // Parse current brightness values
                var displays = this.text.trim().split("|")
                var vals = []
                for (var i = 0; i < displays.length; i++) {
                    var parts = displays[i].split(":")
                    if (parts.length < 3) { vals.push(50); continue }
                    var cur = parseInt(parts[1])
                    var max = parseInt(parts[2])
                    vals.push(max > 0 ? Math.round((cur / max) * 100) : 50)
                }
                root.theaterPrevBrightness = vals

                // pendingPrimary -1 means read-only — just store values, don't dim
                if (theaterBrightnessProc.pendingPrimary === -1) return

                var primary = theaterBrightnessProc.pendingPrimary
                var dim     = theaterBrightnessProc.pendingDim
                var wp      = theaterBrightnessProc.pendingWallpaper

                var rawCmd = (root.settings.commands && root.settings.commands.wallpaper_set)
                    || "awww img -o {display} {wallpaper}"

                for (var j = 0; j < root.displayNames.length; j++) {
                    if (j !== primary) {
                        var connector = root.displayNames[j]
                        var ddcNum = root.ddcMap[connector] || (j + 1)
                        root.execute(root.newUtill(["--ddcsetbrightness", ddcNum, dim]))
                        if (wp !== "") {
                            var wallpaperCmd = rawCmd
                                .replace("{display}", connector)
                                .replace("{wallpaper}", wp)
                            root.execute(wallpaperCmd.split(" "))
                        }
                    }
                }

                root.theaterMode = true
                root.settings.theater.enabled = true
                // Stop wallpaper cycling while theater is active
                wallpaperSwitchTimer.running = false
                root.saveSettings()
            }
        }
    }

    function setTheaterMode(on) {
        var theater = settings.theater || {}
        var primary = (theater.primaryDisplay !== undefined && theater.primaryDisplay !== null)
            ? theater.primaryDisplay
            : root.primaryDisplayIndex
        var dimBrightness  = theater.dimBrightness !== undefined ? theater.dimBrightness : 10
        var theaterWallpaper = theater.wallpaper || ""

        if (on) {
            // Read current brightness first, then dim in the proc callback
            theaterBrightnessProc.pendingDim      = dimBrightness
            theaterBrightnessProc.pendingPrimary  = primary
            theaterBrightnessProc.pendingWallpaper = theaterWallpaper
            theaterBrightnessProc.running = true
        } else {
            // Restore brightness on non-primary displays using correct DDC numbers
            for (var k = 0; k < root.displayNames.length; k++) {
                if (k !== primary) {
                    var restoreConnector = root.displayNames[k]
                    var restoreDdc = root.ddcMap[restoreConnector] || (k + 1)
                    root.execute(root.newUtill(["--ddcsetbrightness", restoreDdc, theaterPrevBrightness[k] || 50]))
                }
            }
            root.nextWallpaper()
            // Resume cycling if it was enabled
            if (root.settings.wallpapers.cycling !== false) {
                wallpaperSwitchTimer.running = true
            }
            theaterMode = false
            settings.theater = settings.theater || {}
            settings.theater.enabled = false
            root.saveSettings()
        }
    }

    Component.onCompleted: {
        BrightnessSystem.read()
        root.migrateDisplayConfig()
        displayRestoreTimer.restart()

        // Reset theater mode if it was left on from previous session
        var theater = settings.theater || {}
        if (theater.enabled === true) {
            settings.theater.enabled = false
            root.saveSettings()
            // Restore cycling if it should be running
            if (root.settings.wallpapers.cycling !== false) {
                wallpaperSwitchTimer.running = true
            }
            // Re-fetch brightness so sliders reflect actual state after reset
            theaterBrightnessProc.pendingDim       = 100  // restore all to full
            theaterBrightnessProc.pendingPrimary   = -1   // -1 = skip dimming, just read
            theaterBrightnessProc.pendingWallpaper = ""
            theaterBrightnessProc.running = true
        }
    }

    // wallpaperMode: 0=auto (follow dark hours), 1=force day, 2=force night
    property int wallpaperMode: root.settings.wallpapers.wallpaperMode || 0


    // FUNCTIONS
    function notify(title, body, icon){
        if (icon){
            notifyServer.iconName = icon
        } else {
            notifyServer.iconName = "notify"
        }
        
        root.execute(["notify-send", title, body])
    }

    function saveSettings(){
        // Refuse to write when the in memory copy is not trustworthy, otherwise
        // one bad parse gets serialised back over a good file permanently
        if (!root.configValid || !settings || typeof settings !== "object") {
            console.log("saveSettings refused: config is not in a healthy state")
            return
        }

        var text = ""
        try {
            text = JSON.stringify(settings, null, 4)
        } catch (e) {
            console.log("saveSettings refused: could not serialise settings — " + e)
            return
        }

        if (!text || text.length < 2 || text === "null" || text === "undefined") {
            console.log("saveSettings refused: serialised config was empty")
            return
        }

        configFile.setText(text)
        root.settingsRevision++
    }

    // cmd() — look up a command by key and return as args array
    // Supports:
    //   {placeholder}   — replaced by value in replacements object
    //   {v-varname}     — replaced by value in settings.variables
    // Shell pipelines (bash -c "...") are handled by wrapping in bash -c automatically
    function cmd(key, replacements) {
        var command = settings.commands[key]
        if (!command) {
            console.log("cmd: unknown key '" + key + "'")
            return []
        }

        // 1. Substitute {v-varname} from settings.variables
        var vars = settings.variables || {}
        command = command.replace(/\{v-([^}]+)\}/g, function(match, varname) {
            return vars[varname] !== undefined ? vars[varname] : match
        })

        // 2. Substitute {placeholder} from caller replacements
        if (replacements) {
            for (var k in replacements) {
                command = command.replace("{" + k + "}", replacements[k])
            }
        }

        // 3. Smart split — if command contains shell operators (&&, ||, |, ;, >)
        //    wrap in bash -c "..." so the shell can evaluate them
        var shellOps = /&&|\|\||[|;&>]/
        if (shellOps.test(command)) {
            return ["bash", "-c", command]
        }

        // 4. Split respecting single and double quoted strings
        var args = []
        var current = ""
        var inSingle = false
        var inDouble = false
        for (var i = 0; i < command.length; i++) {
            var c = command[i]
            if (c === "'" && !inDouble) {
                inSingle = !inSingle
            } else if (c === '"' && !inSingle) {
                inDouble = !inDouble
            } else if (c === " " && !inSingle && !inDouble) {
                if (current.length > 0) { args.push(current); current = "" }
            } else {
                current += c
            }
        }
        if (current.length > 0) args.push(current)
        return args
    }

    // cmdDesc() — get a truncated command string for display in UI
    function cmdDesc(key, maxLen) {
        var command = settings.commands[key] || ""
        var limit = maxLen || 32
        return command.length > limit ? command.substring(0, limit) + "…" : command
    }

    // cmdExec() — look up and immediately execute
    function cmdExec(key, replacements) {
        var args = root.cmd(key, replacements)
        if (args.length > 0) execute(args)
    }

    function copy(text){
        Quickshell.clipboardText = text
    }

    function execute(args){
        var commandArgs = args
        // Only split if a single string was passed (legacy convenience)
        // Never split if multiple args given — paths can contain spaces
        if (commandArgs.length === 1 && typeof commandArgs[0] === "string") {
            if (!commandArgs[0].startsWith("/") && commandArgs[0].includes(" ")){
                commandArgs = args[0].split(" ")
            }
        }
        console.log("Executing -> " + commandArgs)
        Quickshell.execDetached({ command: commandArgs })
    }

    function copyArray(array){
        var newArray = [];
        for (var i = 0; i < array.length; i++){
            newArray.push(array[i]);
        }
        return newArray;
    }

    function combine(listA, listB){
        var newList = copyArray(listA);
        for (var i = 0; i < listB.length; i++){
            newList.push(listB[i]);
        }
        return newList;
    }

    function newUtill(args){
        return combine(root.utill, args);
    }

    function newBatch(commands) {
        // commands: [["funcname", arg1, arg2], ["funcname2"]]
        // Returns: combine(utill, ["--batch", "-funcname", arg1, "-funcname2"])
        var batchArgs = ["--batch"]
        for (var i = 0; i < commands.length; i++) {
            var parts = commands[i]
            batchArgs.push("-" + parts[0])
            for (var j = 1; j < parts.length; j++) {
                batchArgs.push(String(parts[j]))
            }
        }
        return combine(root.utill, batchArgs)
    }

    // parseBatch() — parse batch result into a map of {funcname: result}
    function parseBatch(text) {
        var map = {}
        var lines = text.trim().split(" BATCHED ")
        for (var i = 0; i < lines.length; i++) {
            var idx = lines[i].indexOf(":")
            if (idx === -1) continue
            var key = lines[i].substring(0, idx)
            var val = lines[i].substring(idx + 1)
            map[key] = val
        }
        return map
    }



    function iconSource(name){
        return settings.iconsPath + name + ".png"
    }

    function setWallpaperInterval(ms) {
        // Only writes config — assigning the timer here would break the binding
        // below, which is how the setting stopped taking effect at all
        root.settings.wallpapers.interval = ms
        root.saveSettings()
    }

    function nextWallpaper(){
        wallpaperSwitchTimer.restart()
        checkDarkHour()
    }

    function checkDarkHour(){ 
        // Do nothing if wallpaper cycling is disabled
        if (!settings.wallpapers.cycling) return

        if (!initialDarkHourCheck)
            initialDarkHourCheck = true

        // wallpaperMode overrides the hour check
        if (root.wallpaperMode === 1) {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.day
            launchWallpaperProc()
            return
        }
        if (root.wallpaperMode === 2) {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.night
            launchWallpaperProc()
            return
        }

        var hour = new Date().getHours()
        if (hour >= settings.wallpapers.darkModeHours.at || hour < settings.wallpapers.darkModeHours.before){
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.night
        } else {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.day
        }
        launchWallpaperProc()
    }

    function launchWallpaperProc() {
        var count = (settings.wallpapers.randomWallpaperPerDisplay
                     && root.displayNames.length > 0)
            ? root.displayNames.length : 1
        wallpaperRandomChoice.command = root.newUtill(["--randomfile", wallpaperRandomChoice.wallpaperFolder, count])
        wallpaperRandomChoice.running = true
    }

    function wallColors(){
        return wallpaperColors.colors
    }

    function wallColorsLen(){
        return wallpaperColors.colors.length
    }


    // GLOBAL OBJECTS

    // -- NOTIFICATIONS
    property NotificationServer notifyServer: NotificationServer {
        id: notifyServer
        keepOnReload: true 
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        property string iconName: "notify"
    }

    // -- USB HOTPLUG WATCHER
    property string usbLastMountpoint: ""
    property string usbLastLabel: ""

    // Python handles the full check: finds mountpoint, label, sends notification
    // Returns: "mountpoint|label" on success, "none" if not mounted yet
    Process {
        id: usbMountCheckProc
        property string pendingDevice: ""
        property int retryCount: 0

        function checkDevice(devName) {
            pendingDevice = devName
            retryCount    = 0
            command = root.newUtill(["--usbmountcheck", devName])
            running = true
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var result = this.text.trim()
                console.log("USB mount check result: " + result)

                if (result === "none" || result === "") {
                    // Not mounted yet — retry up to 3 times
                    if (usbMountCheckProc.retryCount < 3) {
                        usbMountCheckProc.retryCount++
                        usbRetryTimer.restart()
                    }
                    return
                }

                var parts = result.split("|")
                var mountpoint = parts[0]
                var label      = parts.length > 1 ? parts[1] : "USB Drive"

                root.usbLastMountpoint = mountpoint
                root.usbLastLabel      = label

                root.execute([
                    "notify-send",
                    "--app-name=USB",
                    "--action=open=Open in Files",
                    "--urgency=normal",
                    "USB Drive Connected",
                    label + " mounted at " + mountpoint
                ])
            }
        }
    }

    Timer {
        id: usbRetryTimer
        interval: 1500
        repeat: false
        onTriggered: {
            var dev = usbMountCheckProc.pendingDevice
            if (dev !== "") {
                usbMountCheckProc.command = root.newUtill(["--usbmountcheck", dev])
                usbMountCheckProc.running = true
            }
        }
    }

    // Permanent udevadm monitor — SplitParser fires onRead per line instantly
    Process {
        id: usbWatcher
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        running: true
        onRunningChanged: if (!running) running = true

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                console.log("udevadm: " + line)

                if (!line.includes(" add ")) return

                var match = line.match(/add\s+(\S+)\s+\(block\)/)
                if (!match) return

                var devName = match[1].split("/").pop()
                console.log("USB device detected: " + devName)

                if (devName.startsWith("loop")) return
                if (devName.startsWith("dm-"))  return
                if (!/\d$/.test(devName)) return

                console.log("USB partition detected: " + devName)
                usbMountInitTimer.devName = devName
                usbMountInitTimer.restart()
            }
        }
    }

    Timer {
        id: usbMountInitTimer
        interval: 1500
        repeat: false
        property string devName: ""
        onTriggered: {
            console.log("Checking mount for: " + devName)
            if (devName !== "") usbMountCheckProc.checkDevice(devName)
        }
    }

    // USB action handled directly in Notification.qml via root.usbLastMountpoint
    
    // -- MEDIA
    property MediaSystem media: MediaSystem{
        id: mediaSystem
    }

    // Temp file cleanup after smart crop wallpaper is set
    Timer {
        id: cleanupTimer
        interval: 3000
        repeat: false
        property string tempFile: ""
        onTriggered: {
            if (tempFile !== "") {
                root.execute(["rm", "-f", tempFile])
                tempFile = ""
            }
        }
    }

    // Smart crop process — handles vertical monitor wallpapers
    Process {
        id: smartCropProc
        property string wallpaper: ""
        property int    monW: 0
        property int    monH: 0
        property string displayName: ""
        property string rawCommand: ""
        property string lastTempFile: ""

        command: root.newUtill(["--smartcrop", wallpaper, monW, monH])

        stdout: StdioCollector {
            onStreamFinished: {
                var result = this.text.trim()
                if (!result) return

                // Clean up previous temp file
                if (smartCropProc.lastTempFile !== ""
                        && smartCropProc.lastTempFile !== smartCropProc.wallpaper) {
                    root.execute(["rm", "-f", smartCropProc.lastTempFile])
                }

                smartCropProc.lastTempFile = result

                // Set the wallpaper with cropped (or original) path
                var cmd = smartCropProc.rawCommand
                    .replace("{wallpaper}", result)
                root.execute(cmd.split(" "))
                // Clean up temp file after a short delay
                if (result !== smartCropProc.wallpaper) {
                    cleanupTimer.tempFile = result
                    cleanupTimer.restart()
                }
            }
        }
    }

    // Portrait wallpaper proc — picks and sets a wallpaper from the portrait folder
    Process {
        id: portraitWallpaperProc
        property string display: ""
        property int    displayIdx: 0
        property string rawCmd: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var wallpaper = this.text.trim().split(",")[0].trim()
                if (!wallpaper) return

                var finalWallpaper = wallpaper

                // Apply smart crop if enabled
                if (root.settings.wallpapers.smartCrop) {
                    var monRes = root.monitorResolutions[portraitWallpaperProc.display]
                    if (monRes && monRes.h > monRes.w) {
                        smartCropProc.wallpaper   = wallpaper
                        smartCropProc.monW        = monRes.w
                        smartCropProc.monH        = monRes.h
                        smartCropProc.displayName = portraitWallpaperProc.display
                        smartCropProc.rawCommand  = portraitWallpaperProc.rawCmd
                        smartCropProc.running     = true
                        return
                    }
                }

                var cmd = portraitWallpaperProc.rawCmd.replace("{wallpaper}", finalWallpaper)
                root.execute(cmd.split(" "))
            }
        }
    }

    // -- THEME
    // Colour derivation moved into the Theme singleton. The quantizer output is
    // read straight from QML, so nothing is generated in Python and nothing is
    // persisted back to config.json.

    // -- WALLPAPERS
    property ColorQuantizer wallpaperColors: ColorQuantizer{
        id: colorQuan
        depth: 3
        rescaleSize: 256
    }
    Timer{
        id: wallpaperSwitchTimer

        // Bound, so changing the interval in settings takes effect immediately.
        // It used to be assigned once at startup and never re-read.
        interval: {
            var bump = root.settingsRevision
            var configured = root.settings.wallpapers
                ? root.settings.wallpapers.interval : 0
            return (configured && configured > 0) ? configured : 900000
        }

        running: root.settings.wallpapers.cycling !== false  // default true if key absent
        repeat: true

        // Replaces the old 100ms first tick that got the wallpaper set at launch
        triggeredOnStart: true

        onTriggered: checkDarkHour()
    }
    Process{
        id: wallpaperRandomChoice
        property string wallpaperFolder: settings.wallpapers.day
        stdout : StdioCollector {
            onStreamFinished: {
                var wallpapers = this.text.trim().split(",")
                var rawCommand = (settings.commands && settings.commands.wallpaper_set)
                    || settings.wallpapers.setWallpaperCommand
                    || "awww img -o {display} {wallpaper}"
                var setWallpaperCommand = rawCommand
                for (var i = 0; i < root.displayNames.length; i++) {
                    var display = root.displayNames[i]

                    var wallpaper = null
                    if (settings.wallpapers.randomWallpaperPerDisplay) {
                        wallpaper = wallpapers[i] ? wallpapers[i].trim() : wallpapers[0].trim()
                    } else {
                        wallpaper = wallpapers[0].trim()
                    }

                    // Portrait monitor — use portrait wallpaper folder if configured
                    var monRes = root.monitorResolutions[display]
                    if (monRes && monRes.h > monRes.w
                            && settings.wallpapers.randomWallpaperPerDisplay
                            && settings.wallpapers.portraitFolder) {
                        portraitWallpaperProc.display    = display
                        portraitWallpaperProc.displayIdx = i
                        portraitWallpaperProc.rawCmd     = rawCommand.replace("{display}", display)
                        portraitWallpaperProc.command    = root.newUtill(["--randomfile", settings.wallpapers.portraitFolder])
                        portraitWallpaperProc.running    = true
                        continue  // handled by portraitWallpaperProc
                    }

                    // Smart crop for vertical monitors if setting enabled
                    var finalWallpaper = wallpaper
                    if (settings.wallpapers.smartCrop && monRes && monRes.h > monRes.w) {
                        console.log("Test")
                        smartCropProc.wallpaper   = wallpaper
                        smartCropProc.monW        = monRes.w
                        smartCropProc.monH        = monRes.h
                        smartCropProc.displayName = display
                        smartCropProc.rawCommand  = rawCommand.replace("{display}", display)
                        smartCropProc.running     = true
                        continue  // handled by smartCropProc
                    }

                    var wallpaperCmd = rawCommand
                        .replace("{display}", display)
                        .replace("{wallpaper}", finalWallpaper)
                    execute(wallpaperCmd.split(" "))
                }
                
                // The index can point past the list when a monitor is absent
                var pick = wallpapers[root.primaryDisplayIndex]
                if (!pick && wallpapers.length > 0)
                    pick = wallpapers[0]
                if (pick)
                    root.wallpaperColors.source = Qt.resolvedUrl(String(pick).trim())
            }
        }
    }

    // ## Overview entry points
    // Two of them, because the bind syntax for the global dispatcher under a Lua
    // config is not something we have confirmed. The IPC route only needs
    // exec_cmd, which is verified to work.

    GlobalShortcut {
        appid: "quickshell"
        name: "overview"
        description: "Toggle the workspace overview"
        onPressed: {
            console.log("overview: global shortcut pressed")
            root.overview.toggle()
        }
    }

    IpcHandler {
        id: overviewIpc
        target: "overview"

        function toggle(): void {
            console.log("overview: ipc toggle")
            root.overview.toggle()
        }

        function open(): void {
            console.log("overview: ipc open")
            root.overview.open()
        }

        function close(): void {
            console.log("overview: ipc close")
            root.overview.close()
        }
    }

    // Set by the app bar once it builds. Lets the settings window reach the
    // add-app picker without duplicating it.
    property var addAppWindow: null

    // Published by their widgets so the quick panel can open the real popups
    // rather than instantiating a second set
    property var audioPopup: null
    property var networkPopup: null
    property var bluetoothPopup: null

    // The popup only polls while it is open, so adapter state comes from the
    // widget, which polls regardless
    property var bluetoothWidget: null
    property var volumeWidget: null
    property var barMenu: null
    property var menuAnchor: null
    property var notificationsPanel: null
    property var calendarWindow: null
    property var clockWindow: null
    property var clockAnchor: null

    // Stamped when anything fires, so the clock widget can react
    property double alertPulse: 0

    // Widgets that own a right click menu. The bar wide handler sits on top, so
    // it has to decline presses that land on these.
    property var rightClickClaims: []

    function claimRightClick(item) {
        if (!item) return
        var next = root.rightClickClaims.slice()
        if (next.indexOf(item) === -1) {
            next.push(item)
            root.rightClickClaims = next
        }
    }
    property var appBar: null

    // -- UI OBJECTS
    property WorkspaceOverview overview: WorkspaceOverview {}
    property MainWindow main: MainWindow {}
}