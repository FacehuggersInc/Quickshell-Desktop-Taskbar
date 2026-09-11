pragma Singleton

import QtQuick

QtObject {
    id: sys

    property var entries: []
    property bool scanned: false

    signal readRequested()
    signal addRequested(string command)
    signal updateRequested(string file, int line, string command)
    signal removeRequested(string file, int line)

    function refresh() { sys.readRequested() }
    function add(command) { if (command && command.trim() !== "") sys.addRequested(command.trim()) }
    function update(file, line, command) { sys.updateRequested(file, line, command) }
    function remove(file, line) { sys.removeRequested(file, line) }
}
