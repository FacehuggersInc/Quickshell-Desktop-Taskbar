import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems

// One window, four views. Cramming the grid, the day, the editor and the feed
// list onto one surface left every one of them short of room.
PanelWindow {
    id: calendarWindow

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:calendar"
    WlrLayershell.keyboardFocus: calendarWindow.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0

    screen: {
        var target = HyprlandSystem.focusedMonitor
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === target)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    property Region glassBlurRegion: Region { item: card }
    BackgroundEffect.blurRegion:
        (calendarWindow.visible && Theme.glass && Theme.blurMode === "protocol")
            ? glassBlurRegion : null

    // "month", "day", "edit", "jump", "subs"
    property string view: "month"
    property string selected: CalendarSystem.todayStamp

    // What the editor is working on; empty id means a new event
    property string editId: ""
    property string editTitle: ""
    property string editDate: ""
    property string editTime: ""
    property string editEnd: ""
    property string editNotes: ""
    property string editRemind: ""
    property string editRepeat: "none"

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    readonly property var dayNames: [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]

    readonly property var cells: {
        var first = new Date(CalendarSystem.viewYear, CalendarSystem.viewMonth, 1)
        var start = new Date(first)
        start.setDate(1 - first.getDay())

        var out = []
        for (var i = 0; i < 42; i++) {
            var moment = new Date(start)
            moment.setDate(start.getDate() + i)
            out.push({
                stamp: CalendarSystem.stamp(moment),
                day: moment.getDate(),
                weekday: moment.getDay(),
                inMonth: moment.getMonth() === CalendarSystem.viewMonth
            })
        }
        return out
    }

    function open() {
        calendarWindow.visible = true
        calendarWindow.view = "month"
        calendarWindow.selected = CalendarSystem.todayStamp
        CalendarSystem.goToday()
        CalendarSystem.subsRequested()
        keyHandler.forceActiveFocus()
    }

    function close() { calendarWindow.visible = false }

    function prettyDate(stamp) {
        var parts = String(stamp).split("-")
        if (parts.length < 3)
            return stamp
        var moment = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1,
                              parseInt(parts[2]))
        return Qt.formatDateTime(moment, "dddd d MMMM yyyy")
    }

    function startNew(stamp) {
        calendarWindow.editId = ""
        calendarWindow.editTitle = ""
        calendarWindow.editDate = stamp
        calendarWindow.editTime = ""
        calendarWindow.editEnd = ""
        calendarWindow.editNotes = ""
        calendarWindow.editRemind = ""
        calendarWindow.editRepeat = "none"
        calendarWindow.view = "edit"
    }

    function startEdit(event) {
        calendarWindow.editId = event.id
        calendarWindow.editTitle = event.title
        calendarWindow.editDate = event.date
        calendarWindow.editTime = event.time
        calendarWindow.editEnd = event.endTime
        calendarWindow.editNotes = event.notes
        calendarWindow.editRemind = event.remind
        calendarWindow.editRepeat = event.repeating ? "weekly" : "none"
        calendarWindow.view = "edit"
    }

    function commitEdit() {
        var fields = {
            title: calendarWindow.editTitle.trim(),
            date: calendarWindow.editDate,
            time: calendarWindow.editTime.trim(),
            endTime: calendarWindow.editEnd.trim(),
            notes: calendarWindow.editNotes.trim(),
            remind: calendarWindow.editRemind,
            repeat: calendarWindow.editRepeat
        }

        if (fields.title === "")
            return

        if (calendarWindow.editId === "")
            CalendarSystem.addRequested(fields)
        else
            CalendarSystem.editRequested(calendarWindow.editId, fields)

        calendarWindow.selected = fields.date
        calendarWindow.view = "day"
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: calendarWindow.visible
        Keys.onEscapePressed: {
            if (calendarWindow.view === "month")
                calendarWindow.close()
            else
                calendarWindow.view = "month"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: calendarWindow.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 1720)
        height: Math.min(parent.height - 60, 1040)
        radius: Theme.radius
        color: Theme.panelScrim
        border.width: Theme.borderWidth
        border.color: Theme.borderStrong
        clip: true

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // ## Header

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.accent, 0.20)

                    Icon {
                        anchors.centerIn: parent
                        iconName: "history"
                        iconSize: 20
                        color: Theme.accentIcon
                    }
                }

                ColumnLayout {
                    spacing: 0

                    Text {
                        text: {
                            if (calendarWindow.view === "day")
                                return calendarWindow.prettyDate(calendarWindow.selected)
                            if (calendarWindow.view === "edit")
                                return calendarWindow.editId === ""
                                    ? "New event" : "Edit event"
                            if (calendarWindow.view === "jump")
                                return "Jump to"
                            if (calendarWindow.view === "subs")
                                return "Subscribed calendars"
                            return calendarWindow.monthNames[CalendarSystem.viewMonth]
                                + " " + CalendarSystem.viewYear
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: 700
                    }

                    Text {
                        text: {
                            if (calendarWindow.view === "month")
                                return CalendarSystem.events.length + " events in view"
                            if (calendarWindow.view === "day")
                                return CalendarSystem.countOn(calendarWindow.selected)
                                    + " on this day"
                            return ""
                        }
                        visible: text !== ""
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                Item { Layout.fillWidth: true }

                // Month navigation, only where it means something
                ActionButton {
                    label: "\u2039"
                    visible: calendarWindow.view === "month"
                    onActivated: CalendarSystem.shiftMonth(-1)
                }

                ActionButton {
                    label: calendarWindow.monthNames[CalendarSystem.viewMonth]
                        + " " + CalendarSystem.viewYear
                    visible: calendarWindow.view === "month"
                    onActivated: calendarWindow.view = "jump"
                }

                ActionButton {
                    label: "\u203A"
                    visible: calendarWindow.view === "month"
                    onActivated: CalendarSystem.shiftMonth(1)
                }

                ActionButton {
                    label: "Today"
                    visible: calendarWindow.view === "month"
                    onActivated: {
                        CalendarSystem.goToday()
                        calendarWindow.selected = CalendarSystem.todayStamp
                    }
                }

                ActionButton {
                    label: "Back"
                    visible: calendarWindow.view !== "month"
                    onActivated: calendarWindow.view =
                        calendarWindow.view === "edit" ? "day" : "month"
                }

                ActionButton {
                    label: "Calendars"
                    visible: calendarWindow.view === "month"
                    onActivated: calendarWindow.view = "subs"
                }

                // Subtle mark rather than a labelled button
                Icon {
                    Layout.leftMargin: 4
                    iconName: "close"
                    iconSize: 18
                    color: calClose.containsMouse ? Theme.danger : Theme.textMute

                    MouseArea {
                        id: calClose
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarWindow.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: CalendarSystem.lastError !== ""
                text: CalendarSystem.lastError
                wrapMode: Text.WordWrap
                color: Theme.warn
                font.family: Theme.fontFamily
                font.pixelSize: Theme.descSize
            }

            // ## Month
            // The grid gets the whole window now that nothing shares it

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                visible: calendarWindow.view === "month"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: 7

                        delegate: Text {
                            required property int index
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: calendarWindow.dayNames[index].substring(0, 3).toUpperCase()
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: 700
                            font.letterSpacing: 0.8
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 6
                    columnSpacing: 6

                    WheelHandler {
                        onWheel: (event) =>
                            CalendarSystem.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
                    }

                    Repeater {
                        model: calendarWindow.cells

                        delegate: Rectangle {
                            id: cell
                            required property var modelData

                            readonly property bool isToday:
                                modelData.stamp === CalendarSystem.todayStamp
                            // All day entries lead, then the timed ones
                            readonly property var dayEvents: {
                                var out = []
                                var all = CalendarSystem.allDayOn(modelData.stamp)
                                for (var i = 0; i < all.length; i++)
                                    out.push(all[i])
                                var timed = CalendarSystem.timedOn(modelData.stamp)
                                for (var j = 0; j < timed.length; j++)
                                    out.push(timed[j])
                                return out
                            }
                            readonly property bool weekend:
                                modelData.weekday === 0 || modelData.weekday === 6

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall

                            color: cellArea.containsMouse
                                ? Theme.alpha(Theme.accent, 0.14)
                                : (cell.weekend
                                    ? Theme.alpha(Theme.scrimBase, 0.45)
                                    : Theme.alpha(Theme.scrimBase, 0.30))

                            border.width: cell.isToday ? 2 : Theme.borderWidth
                            border.color: cell.isToday
                                ? Theme.accent : Theme.alpha(Theme.textBase, 0.08)
                            opacity: modelData.inMonth ? 1.0 : 0.3

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            Text {
                                id: cellDay
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 7
                                text: cell.modelData.day
                                color: cell.isToday ? Theme.accentText : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: cell.isToday ? 700 : 500
                            }

                            // Directly under the date rather than pinned to the
                            // bottom, so a day reads top down
                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: cellDay.bottom
                                anchors.topMargin: 4
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 2

                                Repeater {
                                    model: Math.min(cell.dayEvents.length, 3)

                                    delegate: Rectangle {
                                        required property int index

                                        readonly property var entry: cell.dayEvents[index]
                                        readonly property color tint:
                                            CalendarSystem.colourFor(entry.source)
                                        readonly property bool allDay:
                                            !entry.time || entry.time === ""

                                        width: parent.width
                                        height: 15
                                        radius: 3

                                        // Filled when it takes the whole day,
                                        // outlined when it sits at a time
                                        color: allDay
                                            ? Qt.rgba(tint.r, tint.g, tint.b, 0.55)
                                            : "transparent"
                                        border.width: allDay ? 0 : Theme.borderWidth
                                        border.color: tint

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (parent.allDay ? ""
                                                    : parent.entry.time + " ")
                                                + parent.entry.title
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                        }
                                    }
                                }

                                Text {
                                    visible: cell.dayEvents.length > 3
                                    text: "+" + (cell.dayEvents.length - 3) + " more"
                                    color: Theme.textMute
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                }
                            }

                            MouseArea {
                                id: cellArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    calendarWindow.selected = cell.modelData.stamp
                                    calendarWindow.view = "day"
                                }

                                onDoubleClicked: calendarWindow.startNew(cell.modelData.stamp)
                            }
                        }
                    }
                }
            }

            // ## Day

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                visible: calendarWindow.view === "day"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap

                    ActionButton {
                        label: "Previous day"
                        onActivated: calendarWindow.selected =
                            calendarWindow.shiftDay(calendarWindow.selected, -1)
                    }

                    ActionButton {
                        label: "Next day"
                        onActivated: calendarWindow.selected =
                            calendarWindow.shiftDay(calendarWindow.selected, 1)
                    }

                    Item { Layout.fillWidth: true }

                    SegmentedControl {
                        width: 220
                        options: [
                            { label: "Events", value: "list" },
                            { label: "Timeline", value: "time" }
                        ]
                        value: calendarWindow.dayView
                        onPicked: (v) => calendarWindow.dayView = v
                    }

                    SelectBox {
                        width: 130
                        visible: calendarWindow.dayView === "time"
                        options: [
                            { label: "5 minutes", value: 5 },
                            { label: "10 minutes", value: 10 },
                            { label: "15 minutes", value: 15 },
                            { label: "30 minutes", value: 30 },
                            { label: "1 hour", value: 60 }
                        ]
                        value: calendarWindow.increment
                        onPicked: (v) => calendarWindow.increment = v
                    }

                    ActionButton {
                        label: "Add event"
                        tone: "accent"
                        onActivated: calendarWindow.startNew(calendarWindow.selected)
                    }
                }

                // ## All day
                // Outside the hours, since they do not belong anywhere on it
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: CalendarSystem.allDayOn(calendarWindow.selected).length > 0

                    Repeater {
                        model: CalendarSystem.allDayOn(calendarWindow.selected)

                        delegate: Rectangle {
                            required property var modelData

                            width: allDayLabel.implicitWidth + 26
                            height: 28
                            radius: Theme.radiusSmall
                            color: Qt.rgba(
                                CalendarSystem.colourFor(modelData.source).r,
                                CalendarSystem.colourFor(modelData.source).g,
                                CalendarSystem.colourFor(modelData.source).b, 0.30)
                            border.width: Theme.borderWidth
                            border.color: CalendarSystem.colourFor(modelData.source)

                            Text {
                                id: allDayLabel
                                anchors.centerIn: parent
                                text: modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.valueSize
                                font.weight: 600
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: modelData.source === ""
                                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onDoubleClicked: {
                                    if (modelData.source === "")
                                        calendarWindow.startEdit(modelData)
                                }
                            }
                        }
                    }
                }

                // ## Timeline
                // Midnight to midnight, events drawn across the hours they
                // actually occupy rather than listed one after another

                ScrollView {
                    id: timeScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: calendarWindow.dayView === "time"
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    // Declared, or the view has nothing to scroll against
                    contentWidth: availableWidth
                    contentHeight: 24 * calendarWindow.hourHeight
                        + calendarWindow.timeInset * 2

                    Item {
                        width: timeScroll.availableWidth
                        height: 24 * calendarWindow.hourHeight
                            + calendarWindow.timeInset * 2

                        // One rule per increment, labelled on the hour
                        Repeater {
                            model: Math.round(1440 / calendarWindow.increment)

                            delegate: Item {
                                required property int index

                                readonly property int minutes:
                                    index * calendarWindow.increment
                                readonly property bool onHour: minutes % 60 === 0

                                y: calendarWindow.timeInset
                                    + minutes * (calendarWindow.hourHeight / 60)
                                width: parent.width
                                height: calendarWindow.rowHeight

                                Text {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.topMargin: -6
                                    width: 46
                                    horizontalAlignment: Text.AlignRight
                                    visible: parent.onHour
                                        || calendarWindow.increment >= 30
                                    text: {
                                        var hour = Math.floor(parent.minutes / 60)
                                        var minute = parent.minutes % 60
                                        return (hour < 10 ? "0" : "") + hour + ":"
                                            + (minute < 10 ? "0" : "") + minute
                                    }
                                    color: parent.onHour ? Theme.textDim : Theme.textMute
                                    font.family: Theme.fontFamily
                                    font.pixelSize: parent.onHour ? 10 : 9
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 54
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: Theme.borderWidth
                                    color: Theme.alpha(Theme.textBase,
                                        parent.onHour ? 0.16 : 0.06)
                                }
                            }
                        }

                        // Now, when looking at today
                        Rectangle {
                            visible: calendarWindow.selected === CalendarSystem.todayStamp
                            x: 54
                            width: parent.width - 54
                            height: 2
                            radius: 1
                            color: Theme.danger
                            y: calendarWindow.timeInset + calendarWindow.nowMinutes
                                * (calendarWindow.hourHeight / 60)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: Theme.danger
                            }
                        }

                        Repeater {
                            model: CalendarSystem.timedOn(calendarWindow.selected)

                            delegate: Rectangle {
                                id: block
                                required property var modelData

                                readonly property color tint:
                                    CalendarSystem.colourFor(modelData.source)
                                readonly property bool local: modelData.source === ""

                                x: 58
                                width: parent.width - 68
                                y: calendarWindow.timeInset
                                    + CalendarSystem.minutesOf(modelData.time)
                                        * (calendarWindow.hourHeight / 60)
                                height: Math.max(22,
                                    CalendarSystem.durationOf(modelData)
                                        * (calendarWindow.hourHeight / 60) - 2)

                                radius: Theme.radiusSmall

                                // Outlined, with only a wash inside — a solid
                                // block at this size hides the rules behind it
                                color: Qt.rgba(tint.r, tint.g, tint.b,
                                    blockArea.containsMouse ? 0.30 : 0.14)
                                border.width: 2
                                border.color: block.tint

                                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    radius: 1.5
                                    color: block.tint
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.top: parent.top
                                    anchors.topMargin: 4
                                    spacing: 0

                                    Text {
                                        width: parent.width
                                        text: block.modelData.title
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.valueSize
                                        font.weight: 600
                                    }

                                    Text {
                                        width: parent.width
                                        visible: block.height > 34
                                        text: block.modelData.time
                                            + (block.modelData.endTime !== ""
                                                ? "–" + block.modelData.endTime : "")
                                        color: Theme.textMute
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.descSize
                                    }
                                }

                                MouseArea {
                                    id: blockArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: block.local
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onDoubleClicked: {
                                        if (block.local)
                                            calendarWindow.startEdit(block.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                ScrollView {
                    id: dayScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: calendarWindow.dayView === "list"
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: dayScroll.availableWidth
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            visible: CalendarSystem.eventsOn(
                                calendarWindow.selected).length === 0
                            text: "Nothing on this day. Add event, or double click a day in the month."
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }

                        Repeater {
                            model: CalendarSystem.timedOn(calendarWindow.selected)

                            delegate: Rectangle {
                                id: eventRow
                                required property var modelData

                                readonly property bool local: modelData.source === ""

                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                radius: Theme.radiusSmall
                                color: eventArea.containsMouse
                                    ? Theme.alpha(Theme.accent, 0.14)
                                    : Theme.alpha(Theme.scrimBase, 0.35)
                                border.width: Theme.borderWidth
                                border.color: Theme.alpha(Theme.textBase, 0.08)

                                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 7
                                    width: 3
                                    radius: 1.5
                                    color: CalendarSystem.colourFor(eventRow.modelData.source)
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 18
                                    anchors.right: rowActions.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: eventRow.modelData.title
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.labelSize
                                        font.weight: 600
                                    }

                                    Row {
                                        spacing: 10

                                        Row {
                                            spacing: 3

                                            Icon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                iconName: "history"
                                                iconSize: 11
                                                color: Theme.textMute
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: eventRow.modelData.time !== ""
                                                    ? eventRow.modelData.time
                                                      + (eventRow.modelData.endTime !== ""
                                                          ? "–" + eventRow.modelData.endTime : "")
                                                    : "all day"
                                                color: Theme.textMute
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.descSize
                                            }
                                        }

                                        Row {
                                            spacing: 3
                                            visible: eventRow.modelData.repeating

                                            Icon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                iconName: "refresh"
                                                iconSize: 11
                                                color: Theme.textMute
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "repeats"
                                                color: Theme.textMute
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.descSize
                                            }
                                        }

                                        Row {
                                            spacing: 3
                                            visible: eventRow.modelData.remind !== ""

                                            Icon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                iconName: "notify"
                                                iconSize: 11
                                                color: Theme.textMute
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: eventRow.modelData.remind + "m before"
                                                color: Theme.textMute
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.descSize
                                            }
                                        }

                                        Row {
                                            spacing: 3
                                            visible: !eventRow.local

                                            Icon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                iconName: "download"
                                                iconSize: 11
                                                color: Theme.ok
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "subscribed"
                                                color: Theme.ok
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.descSize
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        visible: eventRow.modelData.notes !== ""
                                        text: eventRow.modelData.notes
                                        elide: Text.ElideRight
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.descSize
                                    }
                                }

                                Row {
                                    id: rowActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    opacity: eventArea.containsMouse ? 1 : 0

                                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                                    ActionButton {
                                        label: "Edit"
                                        visible: eventRow.local
                                        onActivated: calendarWindow.startEdit(eventRow.modelData)
                                    }

                                    ActionButton {
                                        label: "Remove"
                                        tone: "danger"
                                        visible: eventRow.local
                                        onActivated: CalendarSystem.deleteRequested(
                                            eventRow.modelData.id)
                                    }
                                }

                                MouseArea {
                                    id: eventArea
                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                    cursorShape: eventRow.local
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onDoubleClicked: {
                                        if (eventRow.local)
                                            calendarWindow.startEdit(eventRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ## Edit

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                visible: calendarWindow.view === "edit"

                SectionLabel { Layout.fillWidth: true; text: "Event" }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Title"
                    stacked: true

                    InputField {
                        width: parent.width
                        text: calendarWindow.editTitle
                        placeholder: "What is happening"
                        onTextChanged: calendarWindow.editTitle = text
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Notes"
                    stacked: true

                    InputField {
                        width: parent.width
                        text: calendarWindow.editNotes
                        placeholder: "Anything worth remembering"
                        onTextChanged: calendarWindow.editNotes = text
                    }
                }

                SectionLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.sectionGap
                    text: "When"
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Date"
                    description: calendarWindow.prettyDate(calendarWindow.editDate)

                    InputField {
                        width: 150
                        text: calendarWindow.editDate
                        placeholder: "2026-09-15"
                        onTextChanged: calendarWindow.editDate = text
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Time"
                    description: "Leave empty for an all day event"

                    Row {
                        spacing: 6

                        InputField {
                            width: 90
                            text: calendarWindow.editTime
                            placeholder: "14:30"
                            onTextChanged: calendarWindow.editTime = text
                        }

                        InputField {
                            width: 90
                            text: calendarWindow.editEnd
                            placeholder: "until"
                            onTextChanged: calendarWindow.editEnd = text
                        }
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Repeats"

                    SelectBox {
                        width: 160
                        options: [
                            { label: "Once", value: "none" },
                            { label: "Daily", value: "daily" },
                            { label: "Weekly", value: "weekly" },
                            { label: "Monthly", value: "monthly" },
                            { label: "Yearly", value: "yearly" }
                        ]
                        value: calendarWindow.editRepeat
                        onPicked: (v) => calendarWindow.editRepeat = v
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    label: "Remind Me"
                    description: "A notification this long before it starts"

                    SelectBox {
                        width: 160
                        placeholder: "No reminder"
                        options: [
                            { label: "No reminder", value: "" },
                            { label: "5 minutes", value: "5" },
                            { label: "15 minutes", value: "15" },
                            { label: "30 minutes", value: "30" },
                            { label: "1 hour", value: "60" },
                            { label: "2 hours", value: "120" }
                        ]
                        value: calendarWindow.editRemind
                        onPicked: (v) => calendarWindow.editRemind = v
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.sectionGap
                    spacing: Theme.gap

                    ActionButton {
                        label: "Cancel"
                        onActivated: calendarWindow.view = "day"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: calendarWindow.editTitle.trim() === ""
                        text: "A title is required"
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }

                    ActionButton {
                        label: calendarWindow.editId === "" ? "Add Event" : "Save"
                        tone: "accent"
                        enabled: calendarWindow.editTitle.trim() !== ""
                        onActivated: calendarWindow.commitEdit()
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ## Jump

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                visible: calendarWindow.view === "jump"

                // Year centred over the months it applies to
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    Row {
                        anchors.centerIn: parent
                        spacing: 14

                        ActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "\u2039"
                            onActivated: {
                                CalendarSystem.viewYear -= 1
                                CalendarSystem.refresh()
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: CalendarSystem.viewYear
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            font.weight: 700
                        }

                        ActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "\u203A"
                            onActivated: {
                                CalendarSystem.viewYear += 1
                                CalendarSystem.refresh()
                            }
                        }
                    }

                    ActionButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        label: calendarWindow.showYears ? "Hide years" : "Pick a year"
                        onActivated: calendarWindow.showYears = !calendarWindow.showYears
                    }
                }

                SectionLabel { Layout.fillWidth: true; text: "Month" }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240
                    columns: 4
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: 12

                        delegate: Rectangle {
                            required property int index
                            readonly property bool current:
                                index === CalendarSystem.viewMonth

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: current ? Theme.alpha(Theme.accent, 0.30)
                                : (pickArea.containsMouse
                                    ? Theme.alpha(Theme.accent, 0.14)
                                    : Theme.alpha(Theme.scrimBase, 0.30))
                            border.width: Theme.borderWidth
                            border.color: current ? Theme.accentLine
                                                  : Theme.alpha(Theme.textBase, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: calendarWindow.monthNames[index]
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.labelSize
                                font.weight: parent.current ? 700 : 500
                            }

                            MouseArea {
                                id: pickArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    CalendarSystem.viewMonth = index
                                    CalendarSystem.refresh()
                                    calendarWindow.view = "month"
                                }
                            }
                        }
                    }
                }

                SectionLabel {
                    Layout.fillWidth: true
                    visible: calendarWindow.showYears
                    text: "Year"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    visible: calendarWindow.showYears

                    ActionButton {
                        label: "\u2039"
                        onActivated: calendarWindow.jumpYear -= 12
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: calendarWindow.jumpYear + " – " + (calendarWindow.jumpYear + 11)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: 700
                    }

                    ActionButton {
                        label: "\u203A"
                        onActivated: calendarWindow.jumpYear += 12
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    visible: calendarWindow.showYears
                    columns: 6
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: 12

                        delegate: Rectangle {
                            required property int index
                            readonly property int year: calendarWindow.jumpYear + index
                            readonly property bool current:
                                year === CalendarSystem.viewYear

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: current ? Theme.alpha(Theme.accent, 0.30)
                                : (yearArea.containsMouse
                                    ? Theme.alpha(Theme.accent, 0.14)
                                    : Theme.alpha(Theme.scrimBase, 0.30))
                            border.width: Theme.borderWidth
                            border.color: current ? Theme.accentLine
                                                  : Theme.alpha(Theme.textBase, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: parent.year
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.valueSize
                                font.weight: parent.current ? 700 : 500
                            }

                            MouseArea {
                                id: yearArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    CalendarSystem.viewYear = parent.year
                                    CalendarSystem.refresh()
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ## Subscriptions

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                visible: calendarWindow.view === "subs"

                SettingRow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    label: "Add a Calendar"
                    description: "An iCal or webcal address. The calendar has to be "
                        + "reachable without signing in — a private one answers 401."
                    stacked: true

                    RowLayout {
                        width: parent.width
                        spacing: Theme.gap

                        InputField {
                            id: subUrl
                            Layout.fillWidth: true
                            placeholder: "https://example.com/calendar.ics"
                        }

                        InputField {
                            id: subName
                            Layout.preferredWidth: 180
                            placeholder: "Name"
                        }

                        ActionButton {
                            label: "Add"
                            tone: "accent"
                            enabled: subUrl.text.trim() !== ""
                            onActivated: {
                                CalendarSystem.subAddRequested(
                                    subUrl.text.trim(),
                                    subName.text.trim() !== ""
                                        ? subName.text.trim() : subUrl.text.trim())
                                subUrl.text = ""
                                subName.text = ""
                            }
                        }

                        ActionButton {
                            label: "Sync All"
                            busy: CalendarSystem.syncing
                            onActivated: CalendarSystem.syncRequested("")
                        }
                    }
                }

                SettingRow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    label: "Holidays"
                    description: "There is no built in holiday list — they come "
                        + "from a public calendar, same as anything else"
                    stacked: true

                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [
                                { label: "United States", code: "en.usa" },
                                { label: "United Kingdom", code: "en.uk" },
                                { label: "Canada", code: "en.canadian" },
                                { label: "Australia", code: "en.australian" },
                                { label: "Germany", code: "de.german" },
                                { label: "France", code: "fr.french" }
                            ]

                            delegate: ActionButton {
                                required property var modelData

                                label: modelData.label
                                onActivated: CalendarSystem.subAddRequested(
                                    "https://calendar.google.com/calendar/ical/"
                                        + modelData.code
                                        + "%23holiday%40group.v.calendar.google.com"
                                        + "/public/basic.ics",
                                    modelData.label + " holidays")
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: CalendarSystem.subscriptions.length === 0
                    text: "No calendars subscribed."
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }

                Repeater {
                    model: CalendarSystem.subscriptions

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        radius: Theme.radiusSmall
                        color: subArea.containsMouse
                            ? Theme.alpha(Theme.accent, 0.12)
                            : Theme.alpha(Theme.scrimBase, 0.35)
                        border.width: Theme.borderWidth
                        border.color: Theme.alpha(Theme.textBase, 0.08)

                        // The calendar's colour, and the way to change it
                        Rectangle {
                            id: subIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            radius: 13
                            color: CalendarSystem.colourFor(modelData.key)
                            border.width: 2
                            border.color: swatchArea.containsMouse
                                ? Theme.text : Theme.alpha(Theme.textBase, 0.20)

                            MouseArea {
                                id: swatchArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarWindow.colouring =
                                    calendarWindow.colouring === modelData.key
                                        ? "" : modelData.key
                            }
                        }

                        // Opens in place rather than in another window
                        Row {
                            anchors.left: subIcon.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            visible: calendarWindow.colouring === modelData.key
                            z: 5

                            Repeater {
                                model: CalendarSystem.palette

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: modelData
                                    border.width: 2
                                    border.color: pickArea.containsMouse
                                        ? Theme.text : "transparent"

                                    MouseArea {
                                        id: pickArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            CalendarSystem.subColourRequested(
                                                calendarWindow.colouring, modelData)
                                            calendarWindow.colouring = ""
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.left: subIcon.right
                            anchors.leftMargin: 12
                            anchors.right: subActions.left
                            visible: calendarWindow.colouring !== modelData.key
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                text: modelData.name
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.labelSize
                                font.weight: 600
                            }

                            Text {
                                width: parent.width
                                text: modelData.count + " events  ·  " + modelData.url
                                elide: Text.ElideMiddle
                                color: Theme.textMute
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.descSize
                            }
                        }

                        Row {
                            id: subActions
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            ActionButton {
                                label: "Sync"
                                busy: CalendarSystem.syncing
                                onActivated: CalendarSystem.syncRequested(modelData.key)
                            }

                            ActionButton {
                                label: "Remove"
                                tone: "danger"
                                onActivated: CalendarSystem.subRemoveRequested(modelData.key)
                            }
                        }

                        MouseArea {
                            id: subArea
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: "Subscribed events are read only and refresh every 30 minutes. "
                        + "A failed sync keeps whatever it had rather than emptying the "
                        + "calendar."
                    wrapMode: Text.WordWrap
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }
            }
        }
    }

    property int jumpYear: CalendarSystem.viewYear - 5

    // "list" or "time"
    property string dayView: "list"
    property string colouring: ""
    property bool showYears: false

    // Minutes per rule. The hour stretches so a 5 minute grid is genuinely
    // taller than an hourly one rather than just more crowded.
    property int increment: 30
    readonly property int rowHeight: 26

    // The 00:00 label is drawn above its own rule, so the whole thing needs
    // headroom or midnight is cut off by the top of the view
    readonly property int timeInset: 12
    readonly property int hourHeight:
        Math.round((60 / calendarWindow.increment) * calendarWindow.rowHeight)
    property int nowMinutes: 0

    Timer {
        interval: 60000
        repeat: true
        running: calendarWindow.visible
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            calendarWindow.nowMinutes = now.getHours() * 60 + now.getMinutes()
        }
    }

    function shiftDay(stamp, delta) {
        var parts = String(stamp).split("-")
        var moment = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1,
                              parseInt(parts[2]))
        moment.setDate(moment.getDate() + delta)
        return CalendarSystem.stamp(moment)
    }
}
