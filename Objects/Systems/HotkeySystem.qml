pragma Singleton

import QtQuick

QtObject {
    id: sys

    property var binds: []
    property bool scanned: false

    signal readRequested()
    signal addRequested(string key, string command)
    signal updateRequested(string file, int line, string key, string command, string options)
    signal removeRequested(string file, int line)

    function refresh() { sys.readRequested() }

    function add(key, command) {
        if (!key || !command)
            return
        sys.addRequested(key, command)
    }

    function update(file, line, key, command, options) {
        sys.updateRequested(file, line, key, command, options)
    }

    function remove(file, line) {
        sys.removeRequested(file, line)
    }

    // Lua needs the command escaped, not the display string
    function execExpression(command) {
        return 'hl.dsp.exec_cmd("' + String(command).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '")'
    }
}
