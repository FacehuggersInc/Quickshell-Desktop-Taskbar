import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems
import qs.Objects.Window.WorkspaceOverview

ColumnLayout {
    id: page
    spacing: 0

    property string selected: ""

    readonly property var monitors: HyprlandSystem.monitors

    readonly property var current: {
        for (var i = 0; i < page.monitors.length; i++) {
            if (page.monitors[i].name === page.selected)
                return page.monitors[i]
        }
        return page.monitors.length > 0 ? page.monitors[0] : null
    }

    function entry() {
        var m = page.current
        if (!m)
            return null
        var saved = DisplaySystem.entryFor(m.name)
        return {
            x: saved && saved.x !== undefined ? saved.x : m.x,
            y: saved && saved.y !== undefined ? saved.y : m.y,
            width: saved && saved.width ? saved.width : m.nativeWidth,
            height: saved && saved.height ? saved.height : m.nativeHeight,
            refresh: saved && saved.refresh ? saved.refresh : m.refresh,
            scale: saved && saved.scale ? saved.scale : m.scale,
            transform: saved && saved.transform !== undefined ? saved.transform : m.transform,
            enabled: saved && saved.enabled !== undefined ? saved.enabled : !m.disabled
        }
    }

    property int revision: 0

    // ## Placement
    // Monitors cannot overlap in a real layout, so a drop snaps to the nearest
    // edge alignment and is then pushed clear of anything it lands on.

    // In logical pixels. Large values feel magnetic when snapping only happens
    // on release, but fight the cursor when it runs on every move.
    property int snapDistance: 24

    readonly property var overlapping: {
        var bump = page.revision
        var out = []
        var mons = page.monitors
        for (var i = 0; i < mons.length; i++) {
            var a = mons[i]
            for (var j = i + 1; j < mons.length; j++) {
                var b = mons[j]
                if (a.x < b.x + b.w && a.x + a.w > b.x
                        && a.y < b.y + b.h && a.y + a.h > b.y) {
                    if (out.indexOf(a.name) === -1) out.push(a.name)
                    if (out.indexOf(b.name) === -1) out.push(b.name)
                }
            }
        }
        return out
    }

    // Explicit, because doing this automatically rewrote every drop
    function tidyLayout() {
        var mons = page.monitors
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i]
            var placed = page.resolvePlacement(m.name, m.x, m.y, m.w, m.h, true)
            if (placed.x === m.x && placed.y === m.y)
                continue
            page.selected = m.name
            var e = page.entry()
            e.x = placed.x
            e.y = placed.y
            DisplaySystem.applyAndSave(m.name, e)
        }
        page.revision++
    }

    function otherRects(name) {
        var out = []
        for (var i = 0; i < page.monitors.length; i++) {
            var m = page.monitors[i]
            if (m.name === name)
                continue
            var saved = DisplaySystem.entryFor(m.name)
            out.push({
                x: saved && saved.x !== undefined ? saved.x : m.x,
                y: saved && saved.y !== undefined ? saved.y : m.y,
                w: m.w,
                h: m.h
            })
        }
        return out
    }

    function snapAxis(value, candidates) {
        var best = value
        var bestGap = page.snapDistance
        for (var i = 0; i < candidates.length; i++) {
            var gap = Math.abs(value - candidates[i])
            if (gap < bestGap) {
                bestGap = gap
                best = candidates[i]
            }
        }
        return best
    }

    function overlaps(name, x, y, w, h) {
        var others = page.otherRects(name)
        for (var i = 0; i < others.length; i++) {
            var o = others[i]
            if (x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y)
                return true
        }
        return false
    }

    // enforce is false while dragging. Pushing out on every move meant a layout
    // that already overlaps — which yours does — shoved the monitor to a flush
    // position on the first pixel and held it there, so it could never be moved.
    function resolvePlacement(name, x, y, w, h, enforce) {
        var others = page.otherRects(name)

        var xs = [0]
        var ys = [0]
        for (var i = 0; i < others.length; i++) {
            xs.push(others[i].x, others[i].x + others[i].w, others[i].x - w)
            ys.push(others[i].y, others[i].y + others[i].h, others[i].y - h)
        }

        var px = page.snapAxis(x, xs)
        var py = page.snapAxis(y, ys)

        if (enforce === false)
            return { x: Math.round(px), y: Math.round(py) }

        // Push out of whatever it still lands on, along the axis needing the
        // smallest correction
        for (var pass = 0; pass < 8; pass++) {
            var hit = null
            for (var j = 0; j < others.length; j++) {
                var o = others[j]
                if (px < o.x + o.w && px + w > o.x && py < o.y + o.h && py + h > o.y) {
                    hit = o
                    break
                }
            }
            if (!hit)
                break

            var left = (hit.x - w) - px
            var right = (hit.x + hit.w) - px
            var up = (hit.y - h) - py
            var down = (hit.y + hit.h) - py

            var moveX = Math.abs(left) < Math.abs(right) ? left : right
            var moveY = Math.abs(up) < Math.abs(down) ? up : down

            if (Math.abs(moveX) <= Math.abs(moveY))
                px += moveX
            else
                py += moveY
        }

        return { x: Math.round(px), y: Math.round(py) }
    }

    function change(field, value) {
        var m = page.current
        if (!m)
            return
        var e = page.entry()
        var bump = page.revision
        e[field] = value
        DisplaySystem.applyAndSave(m.name, e)
        page.revision++
    }

    Component.onCompleted: {
        if (page.selected === "" && page.monitors.length > 0)
            page.selected = page.monitors[0].name
    }

    // ## Arrangement
    // Monitors at their real relative positions, scaled to fit. Dragging one
    // writes its position back, which is exactly what Hyprland's coordinates are.

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Arrangement"
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.preferredHeight: Math.max(260, Math.min(420, page.width * 0.42))
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.scrimBase, 0.35)
        border.width: Theme.borderWidth
        border.color: Theme.alpha(Theme.textBase, 0.08)
        clip: true

        Item {
            id: canvas
            anchors.fill: parent
            anchors.margins: 18

            readonly property var bounds: {
                var mons = page.monitors
                if (mons.length === 0)
                    return { minX: 0, minY: 0, w: 1, h: 1 }
                var minX = mons[0].x, minY = mons[0].y
                var maxX = mons[0].x + mons[0].w, maxY = mons[0].y + mons[0].h
                for (var i = 1; i < mons.length; i++) {
                    minX = Math.min(minX, mons[i].x)
                    minY = Math.min(minY, mons[i].y)
                    maxX = Math.max(maxX, mons[i].x + mons[i].w)
                    maxY = Math.max(maxY, mons[i].y + mons[i].h)
                }
                return { minX: minX, minY: minY,
                         w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
            }

            readonly property real factor:
                Math.min(width / bounds.w, height / bounds.h)

            readonly property real offsetX: (width - bounds.w * factor) / 2
            readonly property real offsetY: (height - bounds.h * factor) / 2

            Repeater {
                model: page.monitors

                delegate: Rectangle {
                    id: plate
                    required property var modelData

                    readonly property bool isSelected: modelData.name === page.selected

                    // Dragging is resolved on every move rather than on release,
                    // so the plate snaps and refuses to overlap while it is under
                    // the cursor instead of jumping into place at the end
                    property bool dragging: false
                    property real dragX: 0
                    property real dragY: 0

                    x: dragging ? dragX
                                : canvas.offsetX + (modelData.x - canvas.bounds.minX) * canvas.factor
                    y: dragging ? dragY
                                : canvas.offsetY + (modelData.y - canvas.bounds.minY) * canvas.factor
                    width: modelData.w * canvas.factor
                    height: modelData.h * canvas.factor
                    z: dragging ? 10 : 0

                    radius: Theme.radiusSmall
                    // Warned rather than prevented, so it is clear the position
                    // will be corrected without the drag being fought
                    readonly property bool clashing: dragging && page.overlaps(
                        modelData.name, plateArea.placedX, plateArea.placedY,
                        modelData.w, modelData.h)

                    color: clashing ? Theme.alpha(Theme.warn, 0.22)
                        : (isSelected ? Theme.alpha(Theme.accent, 0.22)
                                      : Theme.alpha(Theme.scrimBase, 0.65))
                    border.width: (isSelected || clashing) ? 2 : Theme.borderWidth
                    border.color: clashing ? Theme.warn
                        : (isSelected ? Theme.accent
                                      : Theme.alpha(Theme.textBase, 0.14))

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: plate.modelData.name
                            color: plate.isSelected ? Theme.accentText : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSize
                            font.weight: 700
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: plate.modelData.w + " × " + plate.modelData.h
                                + "  " + plate.modelData.refresh + "Hz"
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }
                    }

                    MouseArea {
                        id: plateArea
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor

                        // Stops the enclosing ScrollView taking the grab
                        preventStealing: true

                        property real grabX: 0
                        property real grabY: 0
                        property int originX: 0
                        property int originY: 0
                        property int placedX: 0
                        property int placedY: 0

                        onPressed: (mouse) => {
                            page.selected = plate.modelData.name
                            var grab = plateArea.mapToItem(canvas, mouse.x, mouse.y)

                            var saved = DisplaySystem.entryFor(plate.modelData.name)
                            plateArea.originX = saved && saved.x !== undefined
                                ? saved.x : plate.modelData.x
                            plateArea.originY = saved && saved.y !== undefined
                                ? saved.y : plate.modelData.y

                            plateArea.placedX = plateArea.originX
                            plateArea.placedY = plateArea.originY
                            // Measured against the canvas, not the plate. Local
                            // coordinates barely change once the plate is
                            // following the cursor, so the delta stayed near
                            // zero and it could never leave its neighbour.
                            plateArea.grabX = grab.x
                            plateArea.grabY = grab.y

                            plate.dragX = plate.x
                            plate.dragY = plate.y
                            plate.dragging = true
                        }

                        onPositionChanged: (mouse) => {
                            if (!plate.dragging)
                                return

                            // Always measured from where the drag started, never
                            // from the last snapped result — compounding made the
                            // plate stick to whatever it first touched
                            var here = plateArea.mapToItem(canvas, mouse.x, mouse.y)
                            var dx = (here.x - plateArea.grabX) / canvas.factor
                            var dy = (here.y - plateArea.grabY) / canvas.factor

                            var placed = page.resolvePlacement(
                                plate.modelData.name,
                                Math.round(plateArea.originX + dx),
                                Math.round(plateArea.originY + dy),
                                plate.modelData.w, plate.modelData.h, false)

                            plateArea.placedX = placed.x
                            plateArea.placedY = placed.y

                            plate.dragX = canvas.offsetX
                                + (placed.x - canvas.bounds.minX) * canvas.factor
                            plate.dragY = canvas.offsetY
                                + (placed.y - canvas.bounds.minY) * canvas.factor
                        }

                        onReleased: {
                            if (!plate.dragging)
                                return
                            plate.dragging = false

                            // Placed exactly where it was dropped. Overlap is
                            // reported, never corrected behind your back — your
                            // own layout overlaps, so enforcing it meant every
                            // drop was rewritten and nothing appeared to move.
                            var e = page.entry()
                            e.x = plateArea.placedX
                            e.y = plateArea.placedY
                            DisplaySystem.applyAndSave(plate.modelData.name, e)
                            page.revision++
                        }

                        onCanceled: plate.dragging = false
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: "Drag a monitor to reposition it. Edges snap to neighbours and overlaps are allowed and only flagged. Positions are stored by the shell and re-applied at startup, since hyprctl changes do not survive a compositor reload."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    // ## Selected monitor

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.preferredHeight: 46
        visible: page.overlapping.length > 0
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.warn, 0.16)
        border.width: Theme.borderWidth
        border.color: Theme.warn

        Text {
            anchors.left: parent.left
            anchors.right: tidyButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            text: page.overlapping.join(", ") + " overlap. That is allowed — "
                + "tidy up only if you want them pushed apart."
            wrapMode: Text.WordWrap
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }

        ActionButton {
            id: tidyButton
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            label: "Tidy Up"
            onActivated: page.tidyLayout()
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: page.current ? page.current.name : "No monitor"
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        visible: page.current !== null
        text: page.current
            ? (page.current.make + " " + page.current.model
               + (page.current.serial !== "" ? "  ·  " + page.current.serial : "")).trim()
            : ""
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null
        iconName: "brightness"
        label: "Enabled"
        description: "Disabling frees the outputs it occupies"

        ToggleSwitch {
            checked: page.current ? page.entry().enabled : true
            onToggled: (v) => page.change("enabled", v)
        }
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null
        label: "Resolution"

        SelectBox {
            width: 170
            options: page.current ? DisplaySystem.resolutionsFor(page.current) : []
            value: page.current ? (page.entry().width + "x" + page.entry().height) : ""
            onPicked: (v) => {
                var parts = String(v).split("x")
                var e = page.entry()
                e.width = parseInt(parts[0])
                e.height = parseInt(parts[1])

                // Keep the refresh rate only if this resolution supports it
                var rates = DisplaySystem.refreshRatesFor(page.current, v)
                var keep = false
                for (var i = 0; i < rates.length; i++)
                    if (rates[i].value === e.refresh) keep = true
                if (!keep && rates.length > 0)
                    e.refresh = rates[0].value

                DisplaySystem.applyAndSave(page.current.name, e)
                page.revision++
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null
        label: "Refresh Rate"

        SelectBox {
            width: 170
            options: page.current
                ? DisplaySystem.refreshRatesFor(
                    page.current, page.entry().width + "x" + page.entry().height)
                : []
            value: page.current ? page.entry().refresh : 0
            onPicked: (v) => page.change("refresh", v)
        }
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null
        label: "Scale"

        SelectBox {
            width: 170
            options: DisplaySystem.scales
            value: page.current ? page.entry().scale : 1
            onPicked: (v) => page.change("scale", v)
        }
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null
        label: "Rotation"

        SelectBox {
            width: 170
            options: DisplaySystem.transforms
            value: page.current ? page.entry().transform : 0
            onPicked: (v) => page.change("transform", v)
        }
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null
        label: "Primary Display"
        description: "Used for theater mode and wallpaper colour"

        ToggleSwitch {
            checked: page.current ? root.primaryDisplay === page.current.name : false
            onToggled: (v) => {
                if (!v || !page.current) return
                root.settings.primaryDisplay = page.current.name
                root.saveSettings()
            }
        }
    }

    // ## Where this monitor is configured

    SectionLabel {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sectionGap
        text: "Hyprland Config"
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.preferredHeight: 58
        visible: page.current !== null
        radius: Theme.radiusSmall
        color: page.current && DisplaySystem.inLua(page.current.name)
            ? Theme.alpha(Theme.accent, 0.14)
            : Theme.alpha(Theme.scrimBase, 0.35)
        border.width: Theme.borderWidth
        border.color: page.current && DisplaySystem.inLua(page.current.name)
            ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2

            Text {
                width: parent.width
                text: page.current && DisplaySystem.inLua(page.current.name)
                    ? "Edits are written into your hl.monitor rule"
                    : "Not in your Hyprland config — the shell stores this layout itself"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.labelSize
                font.weight: 600
            }

            Text {
                width: parent.width
                text: {
                    if (!page.current)
                        return ""
                    var entry = DisplaySystem.configFor(page.current.name)
                    if (entry)
                        return entry.file + " : " + entry.line
                    return "Adding it below writes a new rule grouped with the others"
                }
                elide: Text.ElideMiddle
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
            }
        }
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null && !DisplaySystem.inLua(page.current.name)
        label: "Add to Hyprland Config"
        description: "Writes an hl.monitor rule so the setting survives a reload"

        ActionButton {
            label: "Add Rule"
            tone: "accent"
            onActivated: {
                if (page.current)
                    DisplaySystem.adoptIntoLua(page.current.name, page.entry())
                page.revision++
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        visible: DisplaySystem.configScanned && DisplaySystem.configLines.length === 0
        text: "No hl.monitor rules found in ~/.config/hypr. Every write takes a timestamped backup of the file it touches."
        wrapMode: Text.WordWrap
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: Theme.descSize
    }

    SettingRow {
        Layout.fillWidth: true
        visible: page.current !== null && !DisplaySystem.inLua(page.current.name)
        label: "Forget Saved Layout"
        description: "Drop the shell's stored settings for this monitor"

        ActionButton {
            label: "Forget"
            tone: "danger"
            onActivated: {
                if (page.current) DisplaySystem.forget(page.current.name)
                page.revision++
            }
        }
    }
}
