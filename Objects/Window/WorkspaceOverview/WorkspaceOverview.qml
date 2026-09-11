import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Objects.Theme
import qs.Objects.Systems

PanelWindow {
    id: overview

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:overview"
    WlrLayershell.keyboardFocus: overview.visible ? WlrKeyboardFocus.Exclusive
                                                  : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0

    property Region overlayBlurRegion: Region { item: keyHandler }
    BackgroundEffect.blurRegion:
        (overview.visible && Theme.glass && Theme.blurMode === "protocol")
            ? overview.overlayBlurRegion : null

    screen: {
        var target = HyprlandSystem.focusedMonitor
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === target)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    property real tileHeight: 200
    property real tileSpacing: 26

    // ## Buckets
    // Hidden holding areas, backed by Hyprland special workspaces. A special
    // workspace only exists while it holds a window, so the names are kept in
    // config.json — otherwise an emptied bucket would vanish from the strip.

    readonly property var bucketNames: {
        var names = (root.settings.buckets || []).slice()
        var live = HyprlandSystem.specialWorkspaces()
        for (var i = 0; i < live.length; i++) {
            var short = live[i].name.replace("special:", "")
            if (names.indexOf(short) === -1)
                names.push(short)
        }
        return names
    }

    function addBucket() {
        var names = (root.settings.buckets || []).slice()
        var next = 1
        while (overview.bucketNames.indexOf("bucket-" + next) !== -1) next++
        var name = "bucket-" + next
        names.push(name)
        root.settings.buckets = names
        root.saveSettings()
        return name
    }

    // Buckets created outside the shell keep whatever name they were given
    function bucketLabel(name) {
        return name.indexOf("bucket-") === 0
            ? "Bucket " + name.substring(7)
            : name
    }

    function removeBucket(name) {
        if (HyprlandSystem.windowsOnSpecial(name).length > 0)
            return

        // The tile is about to be destroyed, and onExited will not fire on a
        // destroyed item, so the hover panel would keep a dangling anchor
        hideBucketPreview(name)
        var names = (root.settings.buckets || []).slice()
        var idx = names.indexOf(name)
        if (idx === -1)
            return
        names.splice(idx, 1)
        root.settings.buckets = names
        root.saveSettings()
    }

    // Overlays a bucket onto the focused monitor and toggles it back off again.
    // One dispatch, reversible, and the arrangement inside the bucket survives.
    // ## Hover preview
    // Rendered in the layer rather than inside the tile so the strip does not
    // reflow, and suppressed during a drag so it never sits over a drop target.

    property string hoverBucket: ""
    property var hoverAnchor: null

    function showBucketPreview(name, anchorItem) {
        if (overview.dragAddress !== "")
            return
        overview.hoverBucket = name
        overview.hoverAnchor = anchorItem
    }

    function hideBucketPreview(name) {
        if (overview.hoverBucket === name) {
            overview.hoverBucket = ""
            overview.hoverAnchor = null
        }
    }

    function peekBucket(name) {
        HyprlandSystem.toggleSpecial(name)
        overview.close()
    }

    // Relocates everything in a bucket onto the focused monitor's active
    // workspace. Unlike a peek this is permanent and the bucket ends up empty.
    // Moves are per window because Hyprland 0.56 has no Lua dispatcher that
    // promotes a whole workspace.
    function emptyBucket(name) {
        var mon = HyprlandSystem.monitorByName(HyprlandSystem.focusedMonitor)
        if (!mon)
            return
        var wins = HyprlandSystem.windowsOnSpecial(name)
        for (var i = 0; i < wins.length; i++) {
            HyprlandSystem.moveWindowToWorkspace(wins[i].address, mon.activeWorkspaceId, false)
        }
    }

    signal previewTick()

    function open() {
        HyprlandSystem.refresh()
        overview.visible = true
        keyHandler.forceActiveFocus()
        previewTimer.restart()
    }

    // Captures settle a moment after the overlay maps, and again whenever the
    // layout changes underneath it
    property Timer previewTimer: Timer {
        interval: 120
        repeat: false
        onTriggered: overview.previewTick()
    }

    function close() {
        overview.cancelDrag()
        overview.visible = false
    }

    function toggle() {
        console.log("overview: toggle, visible was " + overview.visible
                    + ", screen " + (overview.screen ? overview.screen.name : "null"))
        if (overview.visible) close()
        else open()
    }

    function focusWindow(win) {
        HyprlandSystem.focusWindow(win.address)
        close()
    }

    function closeWindow(win) {
        HyprlandSystem.closeWindow(win.address)
    }

    // ## Drag
    // The tiles are positioned by binding to real geometry, so dragging the tile
    // itself would break those bindings. A ghost follows the cursor instead and
    // the drop target is resolved by hit testing the monitor tiles.

    property string dragAddress: ""
    property var dragWin: null
    property string dropTarget: ""
    property alias dragLayer: layer

    function beginDrag(win, point) {
        overview.hoverBucket = ""
        overview.hoverAnchor = null
        overview.dragWin = win
        overview.dragAddress = win.address
        updateDrag(point)
    }

    function updateDrag(point) {
        ghost.x = point.x - ghost.width / 2
        ghost.y = point.y - ghost.height / 2
        overview.dropTarget = targetAt(point)
    }

    function cancelDrag() {
        overview.dragAddress = ""
        overview.dragWin = null
        overview.dropTarget = ""
    }

    function endDrag(point) {
        var target = targetAt(point)
        var address = overview.dragAddress
        cancelDrag()

        if (!address)
            return

        var win = HyprlandSystem.windowsByAddress[address]

        // Dropping into empty space makes a new bucket rather than doing nothing
        if (!target) {
            if (!address)
                return
            HyprlandSystem.stashWindow(address, addBucket())
            return
        }

        if (target.indexOf("bucket:") === 0) {
            var bucket = target.substring(7)
            if (win && win.workspaceName === "special:" + bucket)
                return
            HyprlandSystem.stashWindow(address, bucket)
            return
        }

        var name = target.substring(4)
        if (win && win.monitor === name && !win.special)
            return
        HyprlandSystem.moveWindowToMonitor(address, name)
    }

    function contains(item, point) {
        if (!item)
            return false
        var local = item.mapFromItem(layer, point.x, point.y)
        return local.x >= 0 && local.y >= 0
            && local.x <= item.width && local.y <= item.height
    }

    function targetAt(point) {
        for (var b = 0; b < bucketRepeater.count; b++) {
            var bucketItem = bucketRepeater.itemAt(b)
            if (contains(bucketItem, point))
                return "bucket:" + bucketItem.name
        }
        for (var i = 0; i < monitorRepeater.count; i++) {
            var item = monitorRepeater.itemAt(i)
            if (contains(item, point))
                return "mon:" + item.monitor.name
        }
        return ""
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: overview.visible
        Keys.onEscapePressed: overview.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: overview.close()
        }
    }

    Item {
        id: layer
        anchors.fill: parent

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20

            // An escape hatch that does not depend on finding the right tile
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: HyprlandSystem.anySpecialShowing() !== ""
                width: hideText.implicitWidth + 28
                height: 30
                radius: Theme.radiusSmall
                color: hideArea.containsMouse ? Theme.alpha(Theme.accent, 0.24)
                                              : Theme.alpha(Theme.accent, 0.14)
                border.width: Theme.borderWidth
                border.color: Theme.accentLine

                Text {
                    id: hideText
                    anchors.centerIn: parent
                    text: "Hide bucket showing on screen"
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.valueSize
                    font.weight: 600
                }

                MouseArea {
                    id: hideArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprlandSystem.toggleSpecial(
                        HyprlandSystem.anySpecialShowing())
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Buckets"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: 600
            }

            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: overview.width - 120
                spacing: 12

                Repeater {
                    id: bucketRepeater
                    model: overview.bucketNames

                    delegate: BucketTile {
                        required property var modelData

                        name: modelData
                        owner: overview
                    }
                }

                // Placeholder only — the drop target for a new bucket is any
                // empty space, so this is not itself interactive
                Rectangle {
                    visible: overview.bucketNames.length === 0
                    width: Math.max(380, hint.implicitWidth + 56)
                    height: 128
                    radius: Theme.radius
                    color: overview.dragAddress !== "" && overview.dropTarget === ""
                        ? Theme.alpha(Theme.accent, 0.14)
                        : "transparent"
                    border.width: Theme.borderWidth
                    border.color: overview.dragAddress !== "" && overview.dropTarget === ""
                        ? Theme.accentLine : Theme.border

                    Text {
                        id: hint
                        anchors.centerIn: parent
                        text: "drop a window in empty space to make a bucket"
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            Item {
                Layout.preferredHeight: 10
                Layout.fillWidth: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Monitors"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: 600
            }

            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: overview.width - 120
                spacing: overview.tileSpacing

                Repeater {
                    id: monitorRepeater
                    model: HyprlandSystem.monitors

                    delegate: MonitorTile {
                        required property var modelData

                        monitor: modelData
                        owner: overview
                        tileHeight: overview.tileHeight
                    }
                }
            }

            Item {
                Layout.preferredHeight: 18
                Layout.fillWidth: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "drop in empty space to make a bucket · double click a bucket to peek it · "
                    + "middle click to empty it onto this monitor · right click an empty one to remove"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        // ## Bucket hover preview

        Loader {
            id: hoverPreview
            active: overview.hoverBucket !== ""
                && overview.dragAddress === ""
                && overview.hoverAnchor !== null
                && overview.hoverAnchor.width > 0
            z: 90

            sourceComponent: BucketPreview {
                name: overview.hoverBucket
                owner: overview
            }

            visible: active && item && overview.hoverAnchor

            x: {
                if (!overview.hoverAnchor || !item)
                    return 0
                var origin = overview.hoverAnchor.mapToItem(layer, 0, 0)
                var centered = origin.x + overview.hoverAnchor.width / 2 - item.width / 2
                return Math.round(Math.max(12, Math.min(layer.width - item.width - 12, centered)))
            }

            y: {
                if (!overview.hoverAnchor || !item)
                    return 0
                var origin = overview.hoverAnchor.mapToItem(layer, 0, 0)
                var above = origin.y - item.height - 10
                if (above < 12)
                    return Math.round(origin.y + overview.hoverAnchor.height + 10)
                return Math.round(above)
            }
        }

        // ## Ghost

        Rectangle {
            id: ghost
            visible: overview.dragAddress !== ""
            width: 74
            height: 46
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.accent, 0.35)
            border.width: 1
            border.color: Theme.accent
            z: 100

            Text {
                anchors.centerIn: parent
                text: overview.dragWin && overview.dragWin.appClass
                    ? overview.dragWin.appClass.charAt(0).toUpperCase() : "?"
                color: Theme.accentText
                font.family: Theme.fontFamily
                font.weight: 700
                font.pixelSize: 18
            }
        }
    }

    Connections {
        target: HyprlandSystem
        function onChanged() {
            if (!overview.visible)
                return
            if (overview.dragAddress !== ""
                    && !HyprlandSystem.windowsByAddress[overview.dragAddress]) {
                overview.cancelDrag()
            }
            if (overview.hoverBucket !== ""
                    && overview.bucketNames.indexOf(overview.hoverBucket) === -1) {
                overview.hideBucketPreview(overview.hoverBucket)
            }
            previewTimer.restart()
        }
    }
}
