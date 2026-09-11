pragma Singleton

import QtQuick
import Quickshell

QtObject {
    id: sys

    property var entries: []
    property bool scanned: false

    signal readRequested()
    signal setRequested(string mime, string desktopId, bool claim)
    signal clearRequested(string mime, bool unclaim)

    function refresh() { sys.readRequested() }

    // claim writes an Added Association as well, which is what lets an
    // application open a type it never declared support for
    function assign(mime, desktopId, claim) {
        sys.setRequested(mime, desktopId, claim === true)
    }

    function clear(mime, unclaim) {
        sys.clearRequested(mime, unclaim === true)
    }

    // Every installed application, for assigning something the type never
    // advertised a handler for
    readonly property var allApps: {
        var out = []
        var list = DesktopEntries.applications
            ? DesktopEntries.applications.values : []
        for (var i = 0; i < list.length; i++) {
            var entry = list[i]
            if (!entry.id || entry.noDisplay)
                continue
            out.push({ label: entry.name || entry.id, value: entry.id + ".desktop" })
        }
        out.sort(function(a, b) { return a.label.localeCompare(b.label) })
        return out
    }

    // ## Application names
    // The scan returns desktop ids. DesktopEntries already tracks the files, so
    // names are resolved here rather than read a second time in python.

    readonly property var appsById: {
        var out = ({})
        var list = DesktopEntries.applications
            ? DesktopEntries.applications.values : []
        for (var i = 0; i < list.length; i++) {
            var entry = list[i]
            if (entry.id)
                out[entry.id + ".desktop"] = {
                    name: entry.name || entry.id,
                    icon: entry.icon || ""
                }
        }
        return out
    }

    function appName(desktopId) {
        if (!desktopId)
            return ""
        var found = sys.appsById[desktopId]
        return found ? found.name : desktopId.replace(".desktop", "")
    }

    function appIcon(desktopId) {
        if (!desktopId)
            return ""
        var found = sys.appsById[desktopId]
        if (!found || !found.icon)
            return ""
        return Quickshell.iconPath(found.icon, true)
    }

    // ## Category glyphs
    // The top level type is the only reliable grouping, and a glyph per category
    // makes a long list scannable in a way the type strings never will.
    readonly property var categoryIcons: ({
        "text": "copy_content",
        "image": "wallpaper",
        "video": "music_play",
        "audio": "volume_max",
        "application": "open_app",
        "font": "settings",
        "model": "apps",
        "inode": "open_folder",
        "message": "notify",
        "multipart": "apps",
        "chemical": "settings",
        "x-content": "download",
        "x-epoc": "settings"
    })

    function categoryIcon(mime) {
        var top = String(mime).split("/")[0]
        return sys.categoryIcons[top] !== undefined
            ? sys.categoryIcons[top] : "close"
    }

    readonly property var categories: {
        var seen = []
        for (var i = 0; i < sys.entries.length; i++) {
            var top = sys.entries[i].mime.split("/")[0]
            if (seen.indexOf(top) === -1)
                seen.push(top)
        }
        seen.sort()

        var out = [{ label: "All categories", value: "" }]
        for (var j = 0; j < seen.length; j++)
            out.push({ label: seen[j], value: seen[j] })
        return out
    }
}
