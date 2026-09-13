pragma Singleton

import QtQuick

QtObject {
    id: sys

    property var alarms: []
    property var timers: []
    property var tracking: []
    property var reminders: []

    // Timers count down here rather than in the store — only their definition
    // is persisted, since a countdown that survived a reboot would be wrong
    property var running: ({})

    signal readRequested()
    signal alarmAddRequested(string label, string time, string days, string popup)
    signal alarmSetRequested(string id, string field, string value)
    signal alarmDeleteRequested(string id)
    signal timerAddRequested(string label, string seconds, string popup)
    signal timerStartRequested(string label, string seconds, string popup)
    signal timerDeleteRequested(string id)
    signal trackTick(string step, var classes)
    signal trackSession(string appClass)
    signal trackSetRequested(string appClass, string minutes, string popup)
    signal trackResetRequested(string appClass)
    signal reminderAddRequested(string label, string appClass, string match,
                                string seconds, string popup, string auto)
    signal reminderSetRequested(string id, string field, string value)
    signal reminderDeleteRequested(string id)

    // kind is "alarm", "timer" or "tracking"
    signal alert(string kind, string label, bool popup)

    function refresh() { sys.readRequested() }

    function pad(value) { return value < 10 ? "0" + value : String(value) }

    // QML's JavaScript has no Intl, so the zone comes from Qt's own formatter
    readonly property string timeZone: {
        var bump = sys.tickSignal
        var abbreviation = Qt.formatDateTime(new Date(), "t")
        var offset = -(new Date().getTimezoneOffset()) / 60
        var sign = offset >= 0 ? "+" : "\u2212"
        var whole = Math.floor(Math.abs(offset))
        var part = Math.round((Math.abs(offset) - whole) * 60)
        return abbreviation + "  UTC" + sign + whole
            + (part > 0 ? ":" + sys.pad(part) : "")
    }

    property string nowText: ""
    property string nowSeconds: ""

    // Bumped every second so anything showing a countdown re-evaluates
    property int tickSignal: 0

    function tickClock() {
        var now = new Date()
        sys.nowText = sys.pad(now.getHours()) + ":" + sys.pad(now.getMinutes())
        sys.nowSeconds = sys.pad(now.getSeconds())
    }

    // ## Alarms
    // Matched to the minute. An alarm that was missed while the shell was not
    // running stays missed rather than firing late.

    property var firedAlarms: ({})

    // "7:30", "0730" and "7.30" all mean the same thing. Comparing raw strings
    // meant an alarm entered as 7:30 never matched 07:30 and simply never rang.
    function normaliseTime(text) {
        var raw = String(text).trim()
        if (raw === "")
            return ""

        var hour = 0
        var minute = 0
        var match = raw.match(/^(\d{1,2})\s*[:.\s]\s*(\d{1,2})$/)

        if (match) {
            hour = parseInt(match[1])
            minute = parseInt(match[2])
        } else if (/^\d{3,4}$/.test(raw)) {
            hour = parseInt(raw.substring(0, raw.length - 2))
            minute = parseInt(raw.substring(raw.length - 2))
        } else if (/^\d{1,2}$/.test(raw)) {
            hour = parseInt(raw)
        } else {
            return ""
        }

        if (hour > 23 || minute > 59)
            return ""
        return sys.pad(hour) + ":" + sys.pad(minute)
    }

    // A singleton cannot see the shell root, so the shell assigns this
    property bool use24: false

    // Shown in whichever format the bar clock uses
    function displayTime(stamp) {
        var parts = String(stamp).split(":")
        if (parts.length < 2)
            return stamp

        if (sys.use24)
            return stamp

        var hour = parseInt(parts[0])
        var suffix = hour < 12 ? "AM" : "PM"
        var shown = hour % 12
        if (shown === 0)
            shown = 12
        return shown + ":" + parts[1] + " " + suffix
    }

    function checkAlarms() {
        var now = new Date()
        var stamp = sys.pad(now.getHours()) + ":" + sys.pad(now.getMinutes())
        var weekday = now.getDay()
        var key = now.toDateString() + " " + stamp

        for (var i = 0; i < sys.alarms.length; i++) {
            var alarm = sys.alarms[i]
            if (!alarm.enabled)
                continue
            if (sys.normaliseTime(alarm.time) !== stamp)
                continue
            if (alarm.days.length > 0 && alarm.days.indexOf(weekday) === -1)
                continue

            var seen = alarm.id + "@" + key
            if (sys.firedAlarms[seen])
                continue

            sys.firedAlarms[seen] = true
            sys.alert("alarm", alarm.label, alarm.popup)
        }
    }

    // ## Timers

    function startTimer(id, label, seconds, popup) {
        var next = ({})
        for (var key in sys.running)
            next[key] = sys.running[key]

        next[id] = {
            id: id,
            label: label,
            endsAt: Date.now() + seconds * 1000,
            total: seconds,
            popup: popup
        }
        sys.running = next
    }

    function stopTimer(id) {
        var next = ({})
        for (var key in sys.running) {
            if (key !== id)
                next[key] = sys.running[key]
        }
        sys.running = next
    }

    function remaining(id) {
        var entry = sys.running[id]
        if (!entry)
            return 0
        return Math.max(0, Math.round((entry.endsAt - Date.now()) / 1000))
    }

    // The soonest thing about to go off, timer or reminder — the clock drains
    // as this approaches zero
    readonly property var soonest: {
        var bump = sys.tickSignal
        var best = null

        for (var key in sys.running) {
            var left = sys.remaining(key)
            if (best === null || left < best.left)
                best = { id: key, left: left, total: sys.running[key].total }
        }

        for (var other in sys.runningReminders) {
            var entry = sys.runningReminders[other]
            var rest = Math.max(0, Math.round((entry.endsAt - Date.now()) / 1000))
            if (best === null || rest < best.left)
                best = { id: other, left: rest, total: entry.total }
        }

        return best
    }

    readonly property real drain: {
        if (!sys.soonest)
            return -1
        // Only in the last minute; before that the clock says nothing
        if (sys.soonest.left > 60)
            return -1
        return Math.max(0, Math.min(1, sys.soonest.left / 60))
    }

    function checkTimers() {
        // Collected first — stopTimer rebuilds the map, and mutating it while
        // iterating meant a timer could be skipped entirely
        var finished = []
        for (var key in sys.running) {
            if (Date.now() >= sys.running[key].endsAt)
                finished.push(key)
        }

        for (var i = 0; i < finished.length; i++) {
            var entry = sys.running[finished[i]]
            sys.stopTimer(finished[i])
            sys.alert("timer", entry.label, entry.popup)
        }

        sys.checkReminders()
    }

    // The shortest time left on anything running, for the clock to react to
    readonly property int soonestTimer: {
        var bump = sys.tickSignal
        var best = -1
        for (var key in sys.running) {
            var left = Math.max(0,
                Math.round((sys.running[key].endsAt - Date.now()) / 1000))
            if (best === -1 || left < best)
                best = left
        }
        return best
    }

    readonly property bool timerImminent: sys.drain >= 0

    function formatSpan(seconds) {
        var value = Math.max(0, Math.round(seconds))
        var hours = Math.floor(value / 3600)
        var minutes = Math.floor((value % 3600) / 60)
        var rest = value % 60

        if (hours > 0)
            return hours + "h " + sys.pad(minutes) + "m"
        if (minutes > 0)
            return minutes + "m " + sys.pad(rest) + "s"
        return rest + "s"
    }

    function formatTotal(seconds) {
        var value = Math.max(0, Math.round(seconds))
        var hours = Math.floor(value / 3600)
        var minutes = Math.floor((value % 3600) / 60)
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    // ## Reminders
    // A reminder is armed while its target is on screen and counts down like a
    // timer. Its target is an application, or a fragment of a window title
    // within that application.

    property var runningReminders: ({})

    function reminderTargets(entry) {
        var out = []
        var windows = HyprlandSystem.windows
        var needle = String(entry.match || "").toLowerCase()

        for (var i = 0; i < windows.length; i++) {
            if (windows[i].appClass !== entry.appClass)
                continue
            if (needle !== "") {
                var title = String(windows[i].title || "").toLowerCase()
                if (title.indexOf(needle) === -1)
                    continue
            }
            out.push(windows[i])
        }
        return out
    }

    function reminderActive(entry) {
        return sys.runningReminders[entry.id] !== undefined
    }

    function reminderLeft(id) {
        var entry = sys.runningReminders[id]
        if (!entry)
            return 0
        return Math.max(0, Math.round((entry.endsAt - Date.now()) / 1000))
    }

    function startReminder(entry) {
        sys.markDone(entry.id, false)
        sys.noteAbsent(entry.id, false)

        var next = ({})
        for (var key in sys.runningReminders)
            next[key] = sys.runningReminders[key]

        next[entry.id] = {
            id: entry.id,
            label: entry.label,
            appClass: entry.appClass,
            endsAt: Date.now() + entry.seconds * 1000,
            total: entry.seconds,
            popup: entry.popup
        }
        sys.runningReminders = next
    }

    // Stopped by hand. A plain stop is undone by the auto arm on the very next
    // tick, so a deliberate stop has to suppress that until the target goes
    // away — which is what "stop" means to whoever pressed it.
    function dismissReminder(id) {
        sys.stopReminder(id)
        sys.markDone(id, true)
        sys.noteAbsent(id, false)
    }

    function stopReminder(id) {
        var next = ({})
        for (var key in sys.runningReminders) {
            if (key !== id)
                next[key] = sys.runningReminders[key]
        }
        sys.runningReminders = next
    }

    // Whichever reminder is counting down against this application
    function reminderFor(appClass) {
        for (var key in sys.runningReminders) {
            if (sys.runningReminders[key].appClass === appClass)
                return sys.runningReminders[key]
        }
        return null
    }

    // Fired once, and not re-armed until its target has gone away. Without
    // this a reminder rang, stopped, saw its app still open and immediately
    // started over — a loop rather than a reminder.
    property var reminderDone: ({})

    function markDone(id, done) {
        var next = ({})
        for (var key in sys.reminderDone)
            next[key] = sys.reminderDone[key]
        if (done)
            next[id] = true
        else
            delete next[id]
        sys.reminderDone = next
    }

    // How many checks in a row a target has been missing. The window list is
    // rebuilt on every Hyprland event and is briefly empty while that happens,
    // so a single absent reading is not evidence the application closed — and
    // treating it as such cleared the suppression and restarted a reminder that
    // had just been stopped.
    property var absentFor: ({})

    function noteAbsent(id, absent) {
        var next = ({})
        for (var key in sys.absentFor)
            next[key] = sys.absentFor[key]
        next[id] = absent ? (next[id] ? next[id] + 1 : 1) : 0
        sys.absentFor = next
        return next[id]
    }

    function checkReminders() {
        // A snapshot with nothing in it at all is a rebuild, not an empty desk
        var trustworthy = HyprlandSystem.windows.length > 0

        for (var i = 0; i < sys.reminders.length; i++) {
            var entry = sys.reminders[i]
            var present = sys.reminderTargets(entry).length > 0

            if (present) {
                sys.noteAbsent(entry.id, false)

                if (entry.auto && !sys.reminderActive(entry)
                        && !sys.reminderDone[entry.id])
                    sys.startReminder(entry)
                continue
            }

            if (!trustworthy)
                continue

            // Gone for several checks running, so it really did close
            var missing = sys.noteAbsent(entry.id, true)
            if (missing < 4)
                continue

            if (sys.reminderActive(entry))
                sys.stopReminder(entry.id)
            if (sys.reminderDone[entry.id])
                sys.markDone(entry.id, false)
        }

        var finished = []
        for (var key in sys.runningReminders) {
            if (Date.now() >= sys.runningReminders[key].endsAt)
                finished.push(key)
        }

        for (var j = 0; j < finished.length; j++) {
            var due = sys.runningReminders[finished[j]]
            sys.stopReminder(finished[j])
            sys.markDone(finished[j], true)
            sys.alert("tracking", due.label, due.popup)
        }
    }

    // ## Tracking
    // Classes currently on screen, minus the shell itself

    readonly property int step: 30

    property var sessionSeen: ({})

    // ## Windows
    // When each window was first seen, so the active view can show how long a
    // particular window has been open rather than only its application total.
    property var windowSeen: ({})

    function noteWindows() {
        var next = ({})
        var windows = HyprlandSystem.windows

        for (var i = 0; i < windows.length; i++) {
            var address = windows[i].address
            if (!address)
                continue
            next[address] = sys.windowSeen[address]
                ? sys.windowSeen[address] : Date.now()
        }
        sys.windowSeen = next
    }

    function windowAge(address) {
        var started = sys.windowSeen[address]
        if (!started)
            return 0
        return Math.round((Date.now() - started) / 1000)
    }

    // Applications with something on screen, each with its windows
    readonly property var activeApps: {
        var bump = sys.tickSignal
        var groups = ({})
        var windows = HyprlandSystem.windows

        for (var i = 0; i < windows.length; i++) {
            var name = windows[i].appClass
            if (!name || name === "")
                continue
            var lowered = String(name).toLowerCase()
            if (lowered === "quickshell" || lowered === "qs")
                continue

            if (!groups[name])
                groups[name] = []
            groups[name].push({
                address: windows[i].address,
                title: windows[i].title ? windows[i].title : name,
                workspace: windows[i].workspace,
                age: sys.windowAge(windows[i].address)
            })
        }

        var out = []
        for (var key in groups) {
            var total = 0
            for (var j = 0; j < sys.tracking.length; j++) {
                if (sys.tracking[j].appClass === key)
                    total = sys.tracking[j].total
            }
            out.push({ appClass: key, windows: groups[key], total: total })
        }
        out.sort(function(a, b) { return b.windows.length - a.windows.length })
        return out
    }

    function openClasses() {
        var out = []
        var windows = HyprlandSystem.windows
        for (var i = 0; i < windows.length; i++) {
            var name = windows[i].appClass
            if (!name || name === "")
                continue
            var lowered = String(name).toLowerCase()
            if (lowered === "quickshell" || lowered === "qs")
                continue
            if (out.indexOf(name) === -1)
                out.push(name)
        }
        return out
    }

    function tickTracking() {
        sys.noteWindows()
        var open = sys.openClasses()

        // A class that was not open last time counts as a fresh session
        var next = ({})
        for (var i = 0; i < open.length; i++) {
            next[open[i]] = true
            if (!sys.sessionSeen[open[i]])
                sys.trackSession(open[i])
        }
        sys.sessionSeen = next

        if (open.length > 0)
            sys.trackTick(String(sys.step), open)

        sys.checkTrackingReminders(open)
    }

    property var firedTracking: ({})

    function checkTrackingReminders(open) {
        for (var i = 0; i < sys.tracking.length; i++) {
            var entry = sys.tracking[i]
            var minutes = parseInt(entry.reminder)
            if (!minutes || minutes <= 0)
                continue
            if (open.indexOf(entry.appClass) === -1)
                continue
            if (entry.total < minutes * 60)
                continue

            // Once per threshold crossing, not once per tick
            var bucket = Math.floor(entry.total / (minutes * 60))
            var key = entry.appClass + "@" + bucket
            if (sys.firedTracking[key])
                continue

            sys.firedTracking[key] = true
            sys.alert("tracking",
                entry.appClass + " open for " + sys.formatTotal(entry.total),
                entry.popup)
        }
    }

    property Timer secondTick: Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            sys.tickClock()
            sys.tickSignal++
            sys.checkTimers()
        }
    }

    property Timer minuteTick: Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: sys.checkAlarms()
    }

    property Timer trackTimer: Timer {
        interval: sys.step * 1000
        repeat: true
        running: true
        onTriggered: sys.tickTracking()
    }
}
