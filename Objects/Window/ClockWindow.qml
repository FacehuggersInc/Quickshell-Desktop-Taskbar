import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Design.Controls
import qs.Objects.Theme
import qs.Objects.Systems
import qs.Objects.Widgets.Internal

// Alarms, timers and how long things have been open. The clock stays at the top
// across all three, so the window always answers "what time is it" first.
PanelWindow {
    id: clockWindow

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:clock"
    WlrLayershell.keyboardFocus: clockWindow.visible
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
        (clockWindow.visible && Theme.glass && Theme.blurMode === "protocol")
            ? glassBlurRegion : null

    property string view: "alarms"

    function open(which) {
        // Only changes view when asked. Forcing alarms on every open fought
        // whatever tab was showing when it was closed.
        if (which && which !== "")
            clockWindow.view = which
        clockWindow.visible = true
        ClockSystem.refresh()
        keyHandler.forceActiveFocus()
    }

    function close() { clockWindow.visible = false }

    readonly property var dayLetters: ["S", "M", "T", "W", "T", "F", "S"]

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: clockWindow.visible
        Keys.onEscapePressed: clockWindow.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim

        MouseArea {
            anchors.fill: parent
            onClicked: clockWindow.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1200)
        height: Math.min(parent.height - 80, 860)
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

            // ## The clock
            // Same dot matrix as the bar, with seconds and the zone, since this
            // is the one place both are worth the room

            // No frame around it — a bordered box around the clock ate height
            // and made it look like another control
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 76

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    DotMatrix {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ClockSystem.nowText
                        dotSize: 4
                        dotGap: 2
                        charGap: 6
                        onColor: Theme.accentText
                        offColor: Theme.alpha(Theme.textBase, 0.07)
                    }

                    DotMatrix {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ClockSystem.nowSeconds
                        dotSize: 2.5
                        dotGap: 1.5
                        charGap: 4
                        onColor: Theme.textDim
                        offColor: Theme.alpha(Theme.textBase, 0.05)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    text: ClockSystem.timeZone
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.descSize
                }

                // A quiet mark rather than a labelled button
                Icon {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    iconName: "close"
                    iconSize: 17
                    color: closeArea.containsMouse ? Theme.danger : Theme.textMute

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockWindow.close()
                    }
                }
            }

            SegmentedControl {
                Layout.fillWidth: true
                options: [
                    { label: "Alarms", value: "alarms" },
                    { label: "Timers", value: "timers" },
                    { label: "Tracking", value: "tracking" }
                ]
                value: clockWindow.view
                onPicked: (v) => clockWindow.view = v
            }

            // ## Alarms

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                visible: clockWindow.view === "alarms"

                Composer {
                    title: "New alarm"
                    note: "Rings on the selected days"
                    action: "Add alarm"
                    ready: alarmLabel.text.trim() !== ""
                    onSubmitted: {
                        ClockSystem.alarmAddRequested(
                            alarmLabel.text.trim(), alarmTime.value,
                            clockWindow.newDays.join(","),
                            clockWindow.newPopup ? "1" : "0")
                        alarmLabel.text = ""
                        clockWindow.resetDays()
                    }

                    FormField {
                        width: 240
                        caption: "What for"

                        InputField {
                            width: 240
                            id: alarmLabel
                            placeholder: "Wake up"
                        }
                    }

                    FormField {
                        caption: "Time"

                        TimeStepper {
                            id: alarmTime
                            places: ["h", "m"]
                            clock: true
                            hours: 7
                            minutes: 30
                        }
                    }

                    FormField {
                        caption: "Days"
                        hint: "None selected rings once"

                        Row {
                            spacing: 4

                            Repeater {
                                model: 7

                                delegate: Rectangle {
                                    required property int index

                                    readonly property bool picked:
                                        clockWindow.newDays.indexOf(index) !== -1

                                    width: 28
                                    height: 28
                                    radius: Theme.radiusSmall
                                    color: picked ? Theme.alpha(Theme.accent, 0.40)
                                                  : Theme.alpha(Theme.textBase, 0.10)
                                    border.width: Theme.borderWidth
                                    border.color: picked ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: clockWindow.dayLetters[index]
                                        color: parent.picked ? Theme.accentText
                                                             : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: 700
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clockWindow.toggleDay(index)
                                    }
                                }
                            }
                        }
                    }

                    FormField {
                        caption: "When it rings"

                        Row {
                            spacing: 8

                            ToggleSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: clockWindow.newPopup
                                onToggled: (v) => clockWindow.newPopup = v
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Take the screen"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.valueSize
                            }
                        }
                    }
                }

                ScrollView {
                    id: alarmScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: alarmScroll.availableWidth
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            visible: ClockSystem.alarms.length === 0
                            text: "No alarms set."
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }

                        Repeater {
                            model: ClockSystem.alarms

                            delegate: Rectangle {
                                id: alarmRow
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(60,
                                    alarmBody.implicitHeight + 18)
                                radius: Theme.radiusSmall
                                color: Theme.alpha(Theme.scrimBase, 0.35)
                                border.width: Theme.borderWidth
                                border.color: modelData.enabled
                                    ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)
                                opacity: modelData.enabled ? 1.0 : 0.55

                                Text {
                                    id: alarmClock
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ClockSystem.displayTime(alarmRow.modelData.time)
                                    color: Theme.accentText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 22
                                    font.weight: 700
                                }

                                Column {
                                    id: alarmBody
                                    anchors.left: alarmClock.right
                                    anchors.leftMargin: 16
                                    anchors.right: alarmActions.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: alarmRow.modelData.label
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.labelSize
                                        font.weight: 600
                                    }

                                    Text {
                                        width: parent.width
                                        text: {
                                            var bits = []
                                            if (alarmRow.modelData.days.length === 0)
                                                bits.push("once")
                                            else {
                                                var names = []
                                                for (var i = 0; i < alarmRow.modelData.days.length; i++)
                                                    names.push(clockWindow.dayLetters[
                                                        alarmRow.modelData.days[i]])
                                                bits.push(names.join(" "))
                                            }
                                            if (alarmRow.modelData.popup)
                                                bits.push("full screen")
                                            return bits.join("  ·  ")
                                        }
                                        color: Theme.textMute
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.descSize
                                    }
                                }

                                Row {
                                    id: alarmActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    ToggleSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: alarmRow.modelData.enabled
                                        onToggled: (v) => ClockSystem.alarmSetRequested(
                                            alarmRow.modelData.id, "enabled", v ? "1" : "0")
                                    }

                                    ActionButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: "Remove"
                                        tone: "danger"
                                        onActivated: ClockSystem.alarmDeleteRequested(
                                            alarmRow.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ## Timers

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                visible: clockWindow.view === "timers"

                Composer {
                    title: "New timer"
                    note: "Saved so it can be started again"
                    action: "Add timer"
                    ready: timerLabel.text.trim() !== "" && timerAmount.totalSeconds > 0
                    onSubmitted: {
                        ClockSystem.timerAddRequested(
                            timerLabel.text.trim(),
                            String(timerAmount.totalSeconds),
                            clockWindow.timerPopup ? "1" : "0")
                        timerLabel.text = ""
                    }

                    FormField {
                        width: 240
                        caption: "What for"

                        InputField {
                            id: timerLabel
                            width: 240
                            placeholder: "Tea"
                        }
                    }

                    FormField {
                        caption: "Length"

                        TimeStepper {
                            id: timerAmount
                            places: ["h", "m", "s"]
                            clock: false
                            minutes: 10
                        }
                    }

                    FormField {
                        caption: "When it ends"

                        Row {
                            spacing: 8

                            ToggleSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: clockWindow.timerPopup
                                onToggled: (v) => clockWindow.timerPopup = v
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Take the screen"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.valueSize
                            }
                        }
                    }
                }

                ScrollView {
                    id: timerScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: timerScroll.availableWidth
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            visible: ClockSystem.timers.length === 0
                            text: "No timers saved."
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }

                        Repeater {
                            model: ClockSystem.timers

                            delegate: Rectangle {
                                id: timerRow
                                required property var modelData

                                readonly property bool active:
                                    ClockSystem.running[modelData.id] !== undefined
                                readonly property int secondsLeft: {
                                    var bump = ClockSystem.tickSignal
                                    return ClockSystem.remaining(modelData.id)
                                }

                                Layout.fillWidth: true
                                Layout.preferredHeight: 66
                                radius: Theme.radiusSmall
                                color: Theme.alpha(Theme.scrimBase, 0.35)
                                border.width: Theme.borderWidth
                                border.color: timerRow.active
                                    ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)
                                clip: true

                                // Progress as the surface, with a bright edge
                                // so the movement is visible second to second
                                Rectangle {
                                    id: progress
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    visible: timerRow.active
                                    width: parent.width * (1 - timerRow.secondsLeft
                                        / Math.max(1, timerRow.modelData.seconds))
                                    color: timerRow.secondsLeft <= 10
                                        ? Theme.alpha(Theme.danger, 0.25)
                                        : Theme.alpha(Theme.accent, 0.20)

                                    Behavior on width {
                                        NumberAnimation { duration: 950 }
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 2
                                        color: timerRow.secondsLeft <= 10
                                            ? Theme.danger : Theme.accent

                                        SequentialAnimation on opacity {
                                            running: timerRow.active
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 1; to: 0.35; duration: 700 }
                                            NumberAnimation { from: 0.35; to: 1; duration: 700 }
                                        }
                                    }
                                }

                                Text {
                                    id: timerClock
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: timerRow.active
                                        ? ClockSystem.formatSpan(timerRow.secondsLeft)
                                        : ClockSystem.formatSpan(timerRow.modelData.seconds)
                                    color: timerRow.active ? Theme.accentText : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 20
                                    font.weight: 700
                                }

                                Column {
                                    anchors.left: timerClock.right
                                    anchors.leftMargin: 16
                                    anchors.right: timerActions.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: timerRow.modelData.label
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.labelSize
                                        font.weight: 600
                                    }

                                    Text {
                                        width: parent.width
                                        text: timerRow.modelData.popup
                                            ? "full screen when it ends" : "notification only"
                                        color: Theme.textMute
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.descSize
                                    }
                                }

                                Row {
                                    id: timerActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    ActionButton {
                                        label: timerRow.active ? "Stop" : "Start"
                                        tone: timerRow.active ? "neutral" : "accent"
                                        onActivated: {
                                            if (timerRow.active)
                                                ClockSystem.stopTimer(timerRow.modelData.id)
                                            else
                                                ClockSystem.startTimer(
                                                    timerRow.modelData.id,
                                                    timerRow.modelData.label,
                                                    timerRow.modelData.seconds,
                                                    timerRow.modelData.popup)
                                        }
                                    }

                                    ActionButton {
                                        label: "Remove"
                                        tone: "danger"
                                        onActivated: {
                                            ClockSystem.stopTimer(timerRow.modelData.id)
                                            ClockSystem.timerDeleteRequested(
                                                timerRow.modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ## Tracking

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                visible: clockWindow.view === "tracking"

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    spacing: Theme.gap

                    SegmentedControl {
                        width: 330
                        options: [
                            { label: "Active now", value: "active" },
                            { label: "Lifetime", value: "all" },
                            { label: "Reminders", value: "reminders" }
                        ]
                        value: clockWindow.trackView
                        onPicked: (v) => clockWindow.trackView = v
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Lifetime totals, kept across restarts, updates and "
                            + "crashes. The shell does not count itself."
                        wrapMode: Text.WordWrap
                        color: Theme.textMute
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.descSize
                    }
                }

                // ## Active
                // Each application with its own windows beneath it

                ScrollView {
                    id: activeScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: clockWindow.trackView === "active"
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: activeScroll.availableWidth
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            visible: ClockSystem.activeApps.length === 0
                            text: "Nothing open."
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }

                        Repeater {
                            model: ClockSystem.activeApps

                            delegate: ColumnLayout {
                                id: appGroup
                                required property var modelData

                                readonly property bool expanded:
                                    clockWindow.expandedApp === modelData.appClass

                                Layout.fillWidth: true
                                spacing: 2

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 54
                                    radius: Theme.radiusSmall
                                    color: groupArea.containsMouse
                                        ? Theme.alpha(Theme.accent, 0.14)
                                        : Theme.alpha(Theme.scrimBase, 0.35)
                                    border.width: Theme.borderWidth
                                    border.color: Theme.accentLine
                                    clip: true

                                    // A reminder armed against this app fills
                                    // the row as it runs down, the same way a
                                    // timer does
                                    readonly property var armed: {
                                        var bump = ClockSystem.tickSignal
                                        return ClockSystem.reminderFor(
                                            appGroup.modelData.appClass)
                                    }

                                    readonly property int armedLeft: armed
                                        ? ClockSystem.reminderLeft(armed.id) : 0

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        visible: parent.armed !== null
                                        width: parent.armed
                                            ? parent.width * (1 - parent.armedLeft
                                                / Math.max(1, parent.armed.total))
                                            : 0
                                        color: parent.armedLeft <= 60
                                            ? Theme.alpha(Theme.warn, 0.22)
                                            : Theme.alpha(Theme.accent, 0.18)

                                        Behavior on width {
                                            NumberAnimation { duration: 950 }
                                        }
                                    }

                                    Text {
                                        id: groupCaret
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appGroup.expanded ? "\u25BE" : "\u25B8"
                                        color: Theme.textMute
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }

                                    Column {
                                        anchors.left: groupCaret.right
                                        anchors.leftMargin: 10
                                        anchors.right: groupTotal.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: appGroup.modelData.appClass
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.labelSize
                                            font.weight: 600
                                        }

                                        Text {
                                            width: parent.width
                                            text: appGroup.modelData.windows.length
                                                + (appGroup.modelData.windows.length === 1
                                                    ? " window" : " windows")
                                            color: Theme.accentText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.descSize
                                        }
                                    }

                                    Column {
                                        id: groupTotal
                                        anchors.right: parent.right
                                        anchors.rightMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0

                                        Text {
                                            anchors.right: parent.right
                                            text: ClockSystem.formatTotal(
                                                appGroup.modelData.total)
                                            color: Theme.accentText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                            font.weight: 700
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            visible: parent.parent.armed !== null
                                            text: parent.parent.armed
                                                ? ClockSystem.formatSpan(
                                                    parent.parent.armedLeft) + " left"
                                                : ""
                                            color: Theme.warn
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.descSize
                                            font.weight: 600
                                        }
                                    }

                                    MouseArea {
                                        id: groupArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clockWindow.expandedApp =
                                            appGroup.expanded ? "" : appGroup.modelData.appClass
                                    }
                                }

                                // The windows themselves, indented beneath
                                Repeater {
                                    model: appGroup.expanded
                                        ? appGroup.modelData.windows : []

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.leftMargin: 26
                                        Layout.preferredHeight: 42
                                        radius: Theme.radiusSmall
                                        color: Theme.alpha(Theme.scrimBase, 0.25)
                                        border.width: Theme.borderWidth
                                        border.color: Theme.alpha(Theme.textBase, 0.08)

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 6
                                            width: 2
                                            radius: 1
                                            color: Theme.alpha(Theme.accent, 0.5)
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 16
                                            anchors.right: windowAge.left
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.title
                                            elide: Text.ElideRight
                                            color: Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.valueSize
                                        }

                                        Text {
                                            id: windowAge
                                            anchors.right: parent.right
                                            anchors.rightMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "open " + ClockSystem.formatSpan(
                                                modelData.age)
                                            color: Theme.textMute
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.descSize
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ## Reminders

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    visible: clockWindow.trackView === "reminders"

                    Composer {
                        title: "New reminder"
                        note: "Runs while its target is open"
                        action: "Add reminder"
                        ready: reminderLabel.text.trim() !== ""
                            && clockWindow.reminderApp !== ""
                            && reminderAfter.totalSeconds > 0
                        onSubmitted: {
                            ClockSystem.reminderAddRequested(
                                reminderLabel.text.trim(),
                                clockWindow.reminderApp,
                                reminderMatch.text.trim(),
                                String(reminderAfter.totalSeconds),
                                clockWindow.reminderPopup ? "1" : "0",
                                "1")
                            reminderLabel.text = ""
                            reminderMatch.text = ""
                        }

                        FormField {
                            width: 220
                            caption: "What to remind you"

                            InputField {
                                id: reminderLabel
                                width: 220
                                placeholder: "Stand up"
                            }
                        }

                        FormField {
                            width: 170
                            caption: "Application"

                            SelectBox {
                                width: 170
                                placeholder: "Pick one"
                                options: {
                                    var out = []
                                    var seen = []
                                    var apps = ClockSystem.activeApps
                                    for (var i = 0; i < apps.length; i++) {
                                        seen.push(apps[i].appClass)
                                        out.push({ label: apps[i].appClass,
                                                   value: apps[i].appClass })
                                    }
                                    var known = ClockSystem.tracking
                                    for (var j = 0; j < known.length; j++) {
                                        if (seen.indexOf(known[j].appClass) === -1)
                                            out.push({ label: known[j].appClass,
                                                       value: known[j].appClass })
                                    }
                                    return out
                                }
                                value: clockWindow.reminderApp
                                onPicked: (v) => clockWindow.reminderApp = v
                            }
                        }

                        FormField {
                            width: 190
                            caption: "Window contains"
                            hint: "Empty watches the whole app"

                            InputField {
                                id: reminderMatch
                                width: 190
                                placeholder: "part of a title"
                            }
                        }

                        FormField {
                            caption: "After"

                            TimeStepper {
                                id: reminderAfter
                                places: ["h", "m"]
                                clock: false
                                hours: 1
                            }
                        }

                        FormField {
                            caption: "When it fires"

                            Row {
                                spacing: 8

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: clockWindow.reminderPopup
                                    onToggled: (v) => clockWindow.reminderPopup = v
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Take the screen"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.valueSize
                                }
                            }
                        }
                    }

                    ScrollView {
                        id: reminderScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: reminderScroll.availableWidth
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                visible: ClockSystem.reminders.length === 0
                                text: "No reminders set."
                                color: Theme.textMute
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.descSize
                            }

                            Repeater {
                                model: ClockSystem.reminders

                                delegate: Rectangle {
                                    id: reminderRow
                                    required property var modelData

                                    readonly property bool armed: {
                                        var bump = ClockSystem.tickSignal
                                        return ClockSystem.reminderActive(modelData)
                                    }

                                    readonly property int secondsLeft: {
                                        var bump = ClockSystem.tickSignal
                                        return ClockSystem.reminderLeft(modelData.id)
                                    }

                                    readonly property int watching: {
                                        var bump = ClockSystem.tickSignal
                                        return ClockSystem.reminderTargets(modelData).length
                                    }

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 64
                                    radius: Theme.radiusSmall
                                    color: Theme.alpha(Theme.scrimBase, 0.35)
                                    border.width: Theme.borderWidth
                                    border.color: reminderRow.armed
                                        ? Theme.accentLine
                                        : Theme.alpha(Theme.textBase, 0.08)
                                    clip: true

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        visible: reminderRow.armed
                                        width: parent.width * (1 - reminderRow.secondsLeft
                                            / Math.max(1, reminderRow.modelData.seconds))
                                        color: reminderRow.secondsLeft <= 60
                                            ? Theme.alpha(Theme.warn, 0.22)
                                            : Theme.alpha(Theme.accent, 0.18)

                                        Behavior on width {
                                            NumberAnimation { duration: 950 }
                                        }
                                    }

                                    Text {
                                        id: reminderClock
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: reminderRow.armed
                                            ? ClockSystem.formatSpan(reminderRow.secondsLeft)
                                            : ClockSystem.formatSpan(
                                                reminderRow.modelData.seconds)
                                        color: reminderRow.armed
                                            ? Theme.accentText : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 18
                                        font.weight: 700
                                    }

                                    Column {
                                        anchors.left: reminderClock.right
                                        anchors.leftMargin: 16
                                        anchors.right: reminderActions.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: reminderRow.modelData.label
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.labelSize
                                            font.weight: 600
                                        }

                                        Text {
                                            width: parent.width
                                            text: {
                                                var bits = [reminderRow.modelData.appClass]
                                                if (reminderRow.modelData.match !== "")
                                                    bits.push("windows containing \""
                                                        + reminderRow.modelData.match + "\"")
                                                else
                                                    bits.push("whole application")
                                                if (reminderRow.watching > 0)
                                                    bits.push(reminderRow.watching
                                                        + " open")
                                                if (!reminderRow.armed
                                                        && reminderRow.watching > 0)
                                                    bits.push("stopped until it closes")
                                                if (reminderRow.modelData.popup)
                                                    bits.push("full screen")
                                                return bits.join("  ·  ")
                                            }
                                            elide: Text.ElideRight
                                            color: reminderRow.watching > 0
                                                ? Theme.accentText : Theme.textMute
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.descSize
                                        }
                                    }

                                    Row {
                                        id: reminderActions
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        ActionButton {
                                            label: reminderRow.armed ? "Stop" : "Start"
                                            tone: reminderRow.armed ? "neutral" : "accent"
                                            onActivated: {
                                                if (reminderRow.armed)
                                                    ClockSystem.dismissReminder(
                                                        reminderRow.modelData.id)
                                                else
                                                    ClockSystem.startReminder(
                                                        reminderRow.modelData)
                                            }
                                        }

                                        ActionButton {
                                            label: "Remove"
                                            tone: "danger"
                                            onActivated: {
                                                ClockSystem.dismissReminder(
                                                    reminderRow.modelData.id)
                                                ClockSystem.reminderDeleteRequested(
                                                    reminderRow.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ScrollView {
                    id: trackScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: clockWindow.trackView === "all"
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: trackScroll.availableWidth
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            visible: ClockSystem.tracking.length === 0
                            text: "Nothing tracked yet."
                            color: Theme.textMute
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.descSize
                        }

                        Repeater {
                            model: ClockSystem.tracking

                            delegate: Rectangle {
                                id: trackRow
                                required property var modelData

                                readonly property bool open: {
                                    var list = ClockSystem.openClasses()
                                    return list.indexOf(modelData.appClass) !== -1
                                }

                                Layout.fillWidth: true
                                Layout.preferredHeight: 58
                                radius: Theme.radiusSmall
                                color: Theme.alpha(Theme.scrimBase, 0.35)
                                border.width: Theme.borderWidth
                                border.color: trackRow.open
                                    ? Theme.accentLine : Theme.alpha(Theme.textBase, 0.08)

                                Text {
                                    id: trackTotal
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 90
                                    text: ClockSystem.formatTotal(trackRow.modelData.total)
                                    color: Theme.accentText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17
                                    font.weight: 700
                                }

                                Column {
                                    anchors.left: trackTotal.right
                                    anchors.leftMargin: 10
                                    anchors.right: trackActions.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: trackRow.modelData.appClass
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.labelSize
                                        font.weight: 600
                                    }

                                    Text {
                                        width: parent.width
                                        text: {
                                            var bits = [trackRow.modelData.sessions
                                                + " sessions"]
                                            if (trackRow.open) bits.push("open now")
                                            var watchers = 0
                                            for (var i = 0; i < ClockSystem.reminders.length; i++) {
                                                if (ClockSystem.reminders[i].appClass
                                                        === trackRow.modelData.appClass)
                                                    watchers++
                                            }
                                            if (watchers > 0)
                                                bits.push(watchers + " reminder"
                                                    + (watchers === 1 ? "" : "s"))
                                            return bits.join("  ·  ")
                                        }
                                        elide: Text.ElideRight
                                        color: trackRow.open ? Theme.accentText : Theme.textMute
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.descSize
                                    }
                                }

                                Row {
                                    id: trackActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    ActionButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: "Reset"
                                        tone: "danger"
                                        onActivated: ClockSystem.trackResetRequested(
                                            trackRow.modelData.appClass)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Today is preselected, so an alarm added without thinking about days
    // rings on the day you added it rather than silently being a one off
    property var newDays: [new Date().getDay()]

    function resetDays() {
        clockWindow.newDays = [new Date().getDay()]
    }
    property bool newPopup: false
    property bool timerPopup: false
    // What is running now is the useful default; the lifetime list is a lookup
    property string trackView: "active"
    property string reminderApp: ""
    property bool reminderPopup: false
    property string expandedApp: ""

    function toggleDay(index) {
        var next = clockWindow.newDays.slice()
        var at = next.indexOf(index)
        if (at === -1)
            next.push(index)
        else
            next.splice(at, 1)
        clockWindow.newDays = next
    }
}
