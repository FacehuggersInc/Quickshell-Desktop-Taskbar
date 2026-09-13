pragma Singleton

import QtQuick
import Quickshell

// What has been launched from the shell, kept in memory. Distinct from shell
// history, which is what the user typed in a terminal — this is what the bar,
// the run popup and the menu actually started.
QtObject {
    id: sys

    property var apps: []
    property var commands: []

    readonly property int limit: 12

    signal launched(string kind, string label, string payload)

    function remember(list, entry) {
        var next = []
        next.push(entry)
        for (var i = 0; i < list.length && next.length < sys.limit; i++) {
            if (list[i].payload !== entry.payload)
                next.push(list[i])
        }
        return next
    }

    function noteApp(name, command, icon) {
        if (!name || String(name).trim() === "")
            return
        sys.apps = sys.remember(sys.apps, {
            kind: "app",
            label: String(name),
            payload: String(command ? command : name),
            icon: (icon && String(icon) !== "*") ? String(icon) : "",
            at: Date.now()
        })
        sys.launched("app", String(name), String(command ? command : name))
    }

    function noteCommand(command) {
        if (!command || String(command).trim() === "")
            return
        var text = String(command).trim()
        sys.commands = sys.remember(sys.commands, {
            kind: "command",
            label: text,
            payload: text,
            icon: "",
            at: Date.now()
        })
        sys.launched("command", text, text)
    }

    // Newest first, apps and commands interleaved by when they ran
    readonly property var combined: {
        var out = []
        for (var i = 0; i < sys.apps.length; i++)
            out.push(sys.apps[i])
        for (var j = 0; j < sys.commands.length; j++)
            out.push(sys.commands[j])
        out.sort(function(a, b) { return b.at - a.at })
        return out.slice(0, sys.limit)
    }

    // Launcher icons are stored as a path, a theme name, or empty
    function iconFor(icon) {
        if (!icon || icon === "" || icon === "*")
            return ""
        var text = String(icon)
        if (text.indexOf("://") !== -1)
            return text
        if (text.charAt(0) === "/")
            return "file://" + text
        return Quickshell.iconPath(text, true)
    }

    function relative(stamp) {
        var seconds = Math.max(0, Math.round((Date.now() - stamp) / 1000))
        if (seconds < 60)
            return "just now"
        if (seconds < 3600)
            return Math.floor(seconds / 60) + "m ago"
        if (seconds < 86400)
            return Math.floor(seconds / 3600) + "h ago"
        return Math.floor(seconds / 86400) + "d ago"
    }
}
