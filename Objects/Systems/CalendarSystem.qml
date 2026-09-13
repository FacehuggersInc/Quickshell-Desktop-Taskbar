pragma Singleton

import QtQuick

import qs.Objects.Theme

QtObject {
    id: sys

    property var events: []
    property var subscriptions: []
    property bool loaded: false
    property bool syncing: false
    property string lastError: ""

    // The month being shown, and today, kept apart so navigating does not lose
    // where "now" is
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property string todayStamp: sys.stamp(new Date())

    signal readRequested(string from, string to)
    signal addRequested(var fields)
    signal editRequested(string id, var fields)
    signal deleteRequested(string id)
    signal syncRequested(string key)
    signal subsRequested()
    signal subAddRequested(string url, string name)
    signal subRemoveRequested(string key)
    signal subColourRequested(string key, string colour)
    signal reminderDue(var event)

    // ## Colour
    // One per calendar, assigned in the order they were added, so a feed keeps
    // its colour as long as the list order holds. Local events take the accent.
    readonly property var palette: [
        "#e0705a", "#d9a53b", "#5fa86b", "#4f9bd9",
        "#8d6fd1", "#c96aa6", "#3fa9a0", "#b0894a"
    ]

    function colourFor(source) {
        if (!source || source === "")
            return Theme.accent

        for (var i = 0; i < sys.subscriptions.length; i++) {
            if (sys.subscriptions[i].key !== source)
                continue
            // A chosen colour wins over the one assigned by position
            if (sys.subscriptions[i].colour
                    && sys.subscriptions[i].colour !== "")
                return sys.subscriptions[i].colour
            return sys.palette[i % sys.palette.length]
        }
        return Theme.ok
    }

    function pad(value) { return value < 10 ? "0" + value : String(value) }

    function stamp(date) {
        return date.getFullYear() + "-" + sys.pad(date.getMonth() + 1)
            + "-" + sys.pad(date.getDate())
    }

    // A month either side, so the grid's leading and trailing days are filled
    function refresh() {
        var from = new Date(sys.viewYear, sys.viewMonth - 1, 1)
        var to = new Date(sys.viewYear, sys.viewMonth + 2, 0)
        sys.readRequested(sys.stamp(from), sys.stamp(to))
    }

    function shiftMonth(delta) {
        var moment = new Date(sys.viewYear, sys.viewMonth + delta, 1)
        sys.viewYear = moment.getFullYear()
        sys.viewMonth = moment.getMonth()
        sys.refresh()
    }

    function goToday() {
        var now = new Date()
        sys.viewYear = now.getFullYear()
        sys.viewMonth = now.getMonth()
        sys.refresh()
    }

    // All day entries first, then by start time
    function timedOn(stamp) {
        var out = []
        var list = sys.eventsOn(stamp)
        for (var i = 0; i < list.length; i++) {
            if (list[i].time && list[i].time !== "")
                out.push(list[i])
        }
        return out
    }

    function allDayOn(stamp) {
        var out = []
        var list = sys.eventsOn(stamp)
        for (var i = 0; i < list.length; i++) {
            if (!list[i].time || list[i].time === "")
                out.push(list[i])
        }
        return out
    }

    // Minutes from midnight, for laying an event out against the hours
    function minutesOf(clock) {
        if (!clock || clock === "")
            return 0
        var parts = String(clock).split(":")
        return (parseInt(parts[0]) || 0) * 60 + (parseInt(parts[1]) || 0)
    }

    function durationOf(event) {
        var start = sys.minutesOf(event.time)
        if (!event.endTime || event.endTime === "")
            return 60
        var end = sys.minutesOf(event.endTime)
        return end > start ? end - start : 60
    }

    function eventsOn(stamp) {
        var out = []
        for (var i = 0; i < sys.events.length; i++) {
            if (sys.events[i].date === stamp)
                out.push(sys.events[i])
        }
        out.sort(function(a, b) {
            if (a.time === "") return -1
            if (b.time === "") return 1
            return a.time < b.time ? -1 : 1
        })
        return out
    }

    function countOn(stamp) { return sys.eventsOn(stamp).length }

    readonly property var todayEvents: sys.eventsOn(sys.todayStamp)

    // ## Reminders
    // Each event fires once per run. The shell is not a scheduler, so a missed
    // one stays missed rather than arriving late and confusing things.

    property var fired: ({})

    function minutesUntil(event) {
        if (!event.time || event.time === "")
            return -1

        var parts = String(event.time).split(":")
        var when = new Date()
        var pieces = String(event.date).split("-")
        when.setFullYear(parseInt(pieces[0]), parseInt(pieces[1]) - 1, parseInt(pieces[2]))
        when.setHours(parseInt(parts[0]), parseInt(parts[1]), 0, 0)

        return Math.round((when.getTime() - Date.now()) / 60000)
    }

    function checkReminders() {
        var list = sys.todayEvents
        for (var i = 0; i < list.length; i++) {
            var event = list[i]
            var lead = parseInt(event.remind)
            if (!lead || lead <= 0)
                continue

            var key = event.id + "@" + event.date + "@" + event.time
            if (sys.fired[key])
                continue

            var left = sys.minutesUntil(event)
            if (left < 0 || left > lead)
                continue

            sys.fired[key] = true
            sys.reminderDue(event)
        }
    }

    // What the calendar widget reacts to: an event within its reminder window
    readonly property var imminent: {
        var list = sys.todayEvents
        for (var i = 0; i < list.length; i++) {
            var left = sys.minutesUntil(list[i])
            if (left >= 0 && left <= 30)
                return list[i]
        }
        return null
    }

    property Timer reminderTimer: Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: sys.checkReminders()
    }
}
