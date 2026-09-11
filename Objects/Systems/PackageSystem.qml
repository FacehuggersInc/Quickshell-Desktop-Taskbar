pragma Singleton

import QtQuick

QtObject {
    id: sys

    property var packages: []
    property var updates: []
    property string helper: "none"
    property bool scanned: false
    property bool busy: false

    signal readRequested()
    signal updatesRequested()
    signal terminalRequested(string command, string title)

    function refresh() { sys.readRequested() }
    function checkUpdates() { sys.updatesRequested() }

    // ## Handoff
    // Nothing here runs a privileged command itself. The command is handed to a
    // terminal so it is visible and has to be confirmed.

    function updateOne(pkg) {
        if (pkg.source === "flatpak")
            sys.terminalRequested("flatpak update " + pkg.name, "Update " + pkg.name)
        else if (pkg.source === "aur" && sys.helper !== "none")
            sys.terminalRequested(sys.helper + " -S " + pkg.name, "Update " + pkg.name)
        else
            sys.terminalRequested("sudo pacman -S " + pkg.name, "Update " + pkg.name)
    }

    function removeOne(pkg) {
        if (pkg.source === "flatpak")
            sys.terminalRequested("flatpak uninstall " + pkg.name, "Remove " + pkg.name)
        else if (pkg.source === "aur" && sys.helper !== "none")
            sys.terminalRequested(sys.helper + " -Rns " + pkg.name, "Remove " + pkg.name)
        else
            sys.terminalRequested("sudo pacman -Rns " + pkg.name, "Remove " + pkg.name)
    }

    function updateAll() {
        var parts = []
        if (sys.helper !== "none")
            parts.push(sys.helper + " -Syu")
        else
            parts.push("sudo pacman -Syu")
        parts.push("flatpak update")
        sys.terminalRequested(parts.join(" ; "), "Update everything")
    }

    function updateFor(name) {
        for (var i = 0; i < sys.updates.length; i++) {
            if (sys.updates[i].name === name)
                return sys.updates[i]
        }
        return null
    }

    readonly property int updateCount: sys.updates.length
}
