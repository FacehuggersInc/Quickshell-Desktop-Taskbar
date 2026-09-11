pragma Singleton

import QtQuick

QtObject {
    id: sys

    property var devices: []
    property var connections: []
    property var networks: []
    property string wifiRadio: "unknown"
    property bool scanned: false
    property bool busy: false
    property string lastError: ""

    signal readRequested()
    signal scanRequested()
    signal radioRequested(string state)
    signal connectRequested(string kind, string target, string secret)
    signal disconnectRequested(string target)
    signal forgetRequested(string target)

    function refresh() { sys.readRequested() }
    function scan() { sys.scanRequested() }
    function setWifi(on) { sys.radioRequested(on ? "on" : "off") }

    function connectSaved(uuid) { sys.connectRequested("saved", uuid, "") }
    function connectWifi(ssid, secret) { sys.connectRequested("wifi", ssid, secret ? secret : "") }
    function disconnect(uuid) { sys.disconnectRequested(uuid) }
    function forget(uuid) { sys.forgetRequested(uuid) }

    readonly property bool wifiEnabled: sys.wifiRadio === "enabled"

    function savedFor(ssid) {
        for (var i = 0; i < sys.connections.length; i++) {
            if (sys.connections[i].name === ssid)
                return sys.connections[i]
        }
        return null
    }

    function signalIcon(strength) {
        var value = parseInt(strength)
        if (value >= 70) return "wifi_max"
        if (value >= 40) return "wifi_max"
        return "wifi_max"
    }
}
