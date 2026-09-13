import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme

Item {
    id: page

    implicitWidth: parent ? parent.width : 600
    implicitHeight: column.implicitHeight

    property int revision: 0

    readonly property var zones: [
        { key: "left", label: "Left" },
        { key: "center", label: "Centre" },
        { key: "right", label: "Right" }
    ]

    readonly property var catalogue: [
        { id: "menu", label: "Menu", icon: "apps" },
        { id: "workspaces", label: "Workspaces", icon: "apps" },
        { id: "appbar", label: "App Bar", icon: "open_app" },
        { id: "clock", label: "Clock", icon: "history" },
        { id: "date", label: "Calendar", icon: "history" },
        { id: "week", label: "Week", icon: "history" },
        { id: "volume", label: "Volume", icon: "volume_max" },
        { id: "mic", label: "Microphone", icon: "microphone" },
        { id: "media", label: "Media", icon: "music_play" },
        { id: "network", label: "Network", icon: "wired" },
        { id: "bluetooth", label: "Bluetooth", icon: "bluetooth" },
        { id: "tray", label: "Tray", icon: "settings" },
        { id: "notifications", label: "Notifications", icon: "notify" },
        { id: "separator", label: "Separator", icon: "close" }
    ]

    readonly property var defaults: ({
        "left": ["menu", "workspaces"],
        "center": ["appbar"],
        "right": ["media", "clock", "date", "separator", "volume", "mic",
                  "network", "bluetooth", "tray", "notifications"]
    })

    function zoneList(key) {
        var bump = page.revision + root.settingsRevision
        var bar = root.settings.bar || ({})
        return bar[key] !== undefined ? bar[key].slice() : page.defaults[key].slice()
    }

    function setZone(key, list) {
        if (!root.settings.bar)
            root.settings.bar = ({})
        root.settings.bar[key] = list
        root.saveSettings()
        page.revision++
    }

    function meta(id) {
        for (var i = 0; i < page.catalogue.length; i++) {
            if (page.catalogue[i].id === id)
                return page.catalogue[i]
        }
        return { id: id, label: id, icon: "settings" }
    }

    function placedIn(id) {
        if (id === "separator")
            return ""
        for (var i = 0; i < page.zones.length; i++) {
            if (page.zoneList(page.zones[i].key).indexOf(id) !== -1)
                return page.zones[i].key
        }
        return ""
    }

    // ## Drag state
    // A ghost follows the cursor and a caret shows where the drop lands. The
    // chips themselves are laid out by a Row, so moving them directly would
    // fight the layout the same way it did in the monitor editor.

    property string dragId: ""
    property string dragFrom: ""
    property int dragIndex: -1
    property string dropZone: ""
    property int dropIndex: -1

    function beginDrag(id, fromZone, index, point) {
        page.dragId = id
        page.dragFrom = fromZone
        page.dragIndex = index
        page.updateDrag(point)
    }

    function updateDrag(point) {
        ghost.x = point.x - ghost.width / 2
        ghost.y = point.y - ghost.height / 2

        var target = ""
        var index = -1
        for (var i = 0; i < zoneRepeater.count; i++) {
            var panel = zoneRepeater.itemAt(i)
            if (!panel)
                continue
            var local = panel.mapFromItem(dragLayer, point.x, point.y)
            if (local.x >= 0 && local.y >= 0
                    && local.x <= panel.width && local.y <= panel.height) {
                target = panel.zoneKey
                index = panel.indexAt(local.x, local.y)
                break
            }
        }

        page.dropZone = target
        page.dropIndex = index
    }

    function cancelDrag() {
        page.dragId = ""
        page.dragFrom = ""
        page.dragIndex = -1
        page.dropZone = ""
        page.dropIndex = -1
    }

    function endDrag() {
        var id = page.dragId
        var from = page.dragFrom
        var fromIndex = page.dragIndex
        var zone = page.dropZone
        var index = page.dropIndex
        cancelDrag()

        if (!id)
            return

        // Dropped outside every zone — a widget that came from the bar is
        // removed, one from the palette is simply not added
        if (!zone) {
            if (from) {
                var pruned = page.zoneList(from)
                pruned.splice(fromIndex, 1)
                page.setZone(from, pruned)
            }
            return
        }

        if (from === zone) {
            var list = page.zoneList(zone)
            list.splice(fromIndex, 1)
            if (index > fromIndex)
                index -= 1
            list.splice(index, 0, id)
            page.setZone(zone, list)
            return
        }

        if (from) {
            var source = page.zoneList(from)
            source.splice(fromIndex, 1)
            page.setZone(from, source)
        } else if (page.placedIn(id) !== "") {
            return
        }

        var target = page.zoneList(zone)
        target.splice(index, 0, id)
        page.setZone(zone, target)
    }

    ColumnLayout {
        id: column
        width: page.width
        spacing: 0

        SectionLabel {
            Layout.fillWidth: true
            Layout.topMargin: Theme.sectionGap
            text: "Bar Layout"
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: "Drag widgets between zones to arrange them, or out of the bar to remove them."
            wrapMode: Text.WordWrap
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 8

            Repeater {
                id: zoneRepeater
                model: page.zones

                delegate: Rectangle {
                    id: zonePanel
                    required property var modelData

                    readonly property string zoneKey: modelData.key
                    readonly property var items: page.zoneList(modelData.key)
                    readonly property bool hovered: page.dropZone === modelData.key

                    // Wrapped, so the caret has to consider rows as well as columns
                    function indexAt(x, y) {
                        var localX = x - chipRow.x
                        var localY = y - chipRow.y

                        for (var i = 0; i < chipRow.children.length; i++) {
                            var chip = chipRow.children[i]
                            if (chip.chipIndex === undefined)
                                continue

                            var above = localY < chip.y
                            var sameRow = localY >= chip.y && localY <= chip.y + chip.height
                            if (above || (sameRow && localX < chip.x + chip.width / 2))
                                return chip.chipIndex
                        }
                        return zonePanel.items.length
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(92, chipRow.implicitHeight + 40)
                    radius: Theme.radiusSmall
                    color: hovered ? Theme.alpha(Theme.accent, 0.14)
                                   : Theme.alpha(Theme.scrimBase, 0.35)
                    border.width: hovered ? 2 : Theme.borderWidth
                    border.color: hovered ? Theme.accent : Theme.alpha(Theme.textBase, 0.10)

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        text: zonePanel.modelData.label.toUpperCase()
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: 700
                        font.letterSpacing: 1.2
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: zonePanel.items.length === 0
                        text: "drop here"
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }

                    Flow {
                        id: chipRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 26
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Repeater {
                            model: zonePanel.items

                            delegate: BarChip {
                                required property var modelData
                                required property int index

                                widgetId: modelData
                                chipIndex: index
                                owner: page
                                zoneKey: zonePanel.zoneKey
                                dimmed: page.dragId === modelData
                                    && page.dragFrom === zonePanel.zoneKey
                                    && page.dragIndex === index
                            }
                        }
                    }

                    // Where the drop lands
                    Rectangle {
                        id: caret
                        visible: zonePanel.hovered && page.dragId !== ""
                        width: 2
                        height: 30
                        radius: 1
                        color: Theme.accent

                        readonly property var anchorChip: {
                            var at = page.dropIndex
                            for (var i = 0; i < chipRow.children.length; i++) {
                                var chip = chipRow.children[i]
                                if (chip.chipIndex === at)
                                    return { item: chip, after: false }
                            }
                            var last = zonePanel.items.length - 1
                            for (var j = 0; j < chipRow.children.length; j++) {
                                var c = chipRow.children[j]
                                if (c.chipIndex === last)
                                    return { item: c, after: true }
                            }
                            return null
                        }

                        x: anchorChip
                            ? chipRow.x + anchorChip.item.x
                              + (anchorChip.after ? anchorChip.item.width + 2 : -4)
                            : chipRow.x
                        y: anchorChip ? chipRow.y + anchorChip.item.y + 2 : chipRow.y + 2
                    }
                }
            }
        }

        SectionLabel {
            Layout.fillWidth: true
            Layout.topMargin: Theme.sectionGap
            text: "Available Widgets"
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 6

            Repeater {
                model: page.catalogue

                delegate: BarChip {
                    required property var modelData

                    widgetId: modelData.id
                    chipIndex: -1
                    owner: page
                    zoneKey: ""
                    dimmed: page.placedIn(modelData.id) !== ""
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: "The settings button is always last on the right — the quick panel and settings window are anchored to it."
            wrapMode: Text.WordWrap
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }

    }

    // ## Drag layer
    // A sibling of the layout, not a child of it

    Item {
        id: dragLayer
        anchors.fill: parent
        z: 100

        Rectangle {
            id: ghost
            visible: page.dragId !== ""
            width: ghostText.implicitWidth + 34
            height: 30
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.accent, 0.35)
            border.width: 1
            border.color: Theme.accent

            Icon {
                id: ghostIcon
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                iconName: page.meta(page.dragId).icon
                iconSize: 14
                color: Theme.accentText
            }

            Text {
                id: ghostText
                anchors.left: ghostIcon.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: page.meta(page.dragId).label
                color: Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.valueSize
                font.weight: 700
            }
        }
    }
}
