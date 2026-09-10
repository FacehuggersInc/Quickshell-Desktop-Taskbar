import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Theme

Item {
    id: net

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property string style: {
        var w = root.settings.widgets || {}
        return w.networkStyle === "text" ? "text" : "dots"
    }

    property string netInterface: "..."
    property string netType: "unknown"
    property string netVpn: "no"

    // ## Throughput
    // Read straight from /proc/net/dev. The old path spawned python every 1.5s
    // and that call slept half a second to take its own second sample.

    property real downRate: 0
    property real upRate: 0
    property real lastRx: -1
    property real lastTx: -1

    readonly property int columns: 12
    readonly property int bandRows: 3
    property var downHistory: []
    property var upHistory: []

    FileView {
        id: netDev
        path: "/proc/net/dev"
        blockLoading: true
    }

    function levelFor(rate) {
        if (rate < 8 * 1024) return 0
        if (rate < 128 * 1024) return 1
        if (rate < 1024 * 1024) return 2
        return 3
    }

    function sample() {
        var text = ""
        try {
            text = netDev.text()
        } catch (e) {
            return
        }
        netDev.reload()

        if (!text)
            return

        var rx = 0
        var tx = 0
        var lines = text.split("\n")
        for (var i = 2; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var split = line.split(":")
            if (split.length < 2) continue
            var name = split[0].trim()
            if (name === "lo" || name.indexOf("veth") === 0 || name.indexOf("br-") === 0)
                continue
            var fields = split[1].trim().split(/\s+/)
            if (fields.length < 10) continue
            rx += parseFloat(fields[0])
            tx += parseFloat(fields[8])
        }

        if (net.lastRx >= 0) {
            net.downRate = Math.max(0, rx - net.lastRx)
            net.upRate = Math.max(0, tx - net.lastTx)

            var down = net.downHistory.slice()
            var up = net.upHistory.slice()
            down.push(net.levelFor(net.downRate))
            up.push(net.levelFor(net.upRate))
            while (down.length > net.columns) down.shift()
            while (up.length > net.columns) up.shift()
            net.downHistory = down
            net.upHistory = up
        }

        net.lastRx = rx
        net.lastTx = tx
    }

    function readable(rate) {
        if (rate >= 1024 * 1024)
            return (rate / (1024 * 1024)).toFixed(1) + " MB/s"
        if (rate >= 1024)
            return Math.round(rate / 1024) + " KB/s"
        return Math.round(rate) + " B/s"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: net.sample()
    }

    // Interface identity changes rarely, so it does not need the fast cadence
    Process {
        id: infoProc
        command: root.newUtill(["--getnetworkinfo"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length < 3) return
                net.netInterface = parts[0]
                net.netType = parts[1]
                net.netVpn = parts[2]
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: { if (!infoProc.running) infoProc.running = true }
    }

    NetworkPopup { id: networkPopup }

    RowLayout {
        id: row
        spacing: 6

        Icon {
            id: netIcon
            Layout.alignment: Qt.AlignVCenter
            iconName: net.netVpn !== "no" ? "vpn"
                : net.netType === "wireless" ? "wifi_max"
                : "wired"
            iconSize: 18
            color: net.netVpn !== "no" ? Theme.ok : Theme.accentIcon
        }

        // ## Meter
        // Download on the top band, upload mirrored below, newest column on the
        // right. Same dot language as the clock.

        Item {
            Layout.alignment: Qt.AlignVCenter
            visible: net.style === "dots"
            implicitWidth: net.columns * 3 - 1
            implicitHeight: net.bandRows * 2 * 3 + 2

            Repeater {
                model: net.columns * net.bandRows * 2

                delegate: Item {
                    id: meterCell
                    required property int index

                    readonly property int column: index % net.columns
                    readonly property int cellRow: Math.floor(index / net.columns)
                    readonly property bool isDown: cellRow < net.bandRows

                    readonly property int level: isDown
                        ? (net.downHistory[column] !== undefined ? net.downHistory[column] : 0)
                        : (net.upHistory[column] !== undefined ? net.upHistory[column] : 0)

                    // Download fills upward from the middle, upload downward
                    readonly property int depth: isDown
                        ? net.bandRows - cellRow
                        : cellRow - net.bandRows + 1

                    readonly property bool lit: depth <= level

                    x: column * 3
                    y: cellRow * 3 + (isDown ? 0 : 2)
                    width: 2
                    height: 2

                    Rectangle {
                        anchors.fill: parent
                        radius: 1
                        color: meterCell.lit
                            ? (meterCell.isDown ? Theme.accentText : Theme.warn)
                            : Theme.alpha(Theme.textBase, 0.07)

                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: net.style === "text"
            text: net.netInterface
            color: net.netVpn !== "no" ? Theme.ok : Theme.text
            font.family: Theme.fontFamily
            font.weight: 500
            font.pixelSize: 16
        }
    }

    Tooltip {
        id: netTooltip
        text: (net.netVpn !== "no" ? "VPN: " + net.netVpn : net.netInterface)
            + "   down " + net.readable(net.downRate)
            + "   up " + net.readable(net.upRate)
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) netTooltip.showAt(point)
            else netTooltip.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: networkPopup.toggle(net)
    }
}
