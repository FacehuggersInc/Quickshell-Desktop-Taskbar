import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// Every time input in the shell. Each place is a column with an arrow above and
// below it, so a value is set by pointing at it rather than by knowing a format.
//
// places is any of "h", "m", "s" — alarms take hours and minutes, timers add
// seconds, reminders drop them.
Rectangle {
    id: control

    property var places: ["h", "m"]

    property int hours: 0
    property int minutes: 0
    property int seconds: 0

    // Alarms are a clock face; durations are a span and never wrap to a
    // meridiem or clamp an hour at 23
    property bool clock: true

    signal edited()

    readonly property bool wide: {
        var widgets = root.settings.widgets || ({})
        return widgets.clock24 === true
    }

    readonly property string value:
        control.pad(control.hours) + ":" + control.pad(control.minutes)

    readonly property int totalSeconds:
        control.hours * 3600 + control.minutes * 60 + control.seconds

    function pad(value) { return value < 10 ? "0" + value : String(value) }

    function setFromTime(text) {
        var parts = String(text).split(":")
        if (parts.length < 2)
            return
        control.hours = Math.max(0, Math.min(23, parseInt(parts[0]) || 0))
        control.minutes = Math.max(0, Math.min(59, parseInt(parts[1]) || 0))
    }

    function setFromSeconds(total) {
        var value = Math.max(0, Math.round(total))
        control.hours = Math.floor(value / 3600)
        control.minutes = Math.floor((value % 3600) / 60)
        control.seconds = value % 60
    }

    function limitFor(place) {
        if (place === "h")
            return control.clock ? 23 : 99
        return 59
    }

    function valueFor(place) {
        if (place === "h")
            return control.hours
        if (place === "m")
            return control.minutes
        return control.seconds
    }

    function apply(place, next) {
        var limit = control.limitFor(place)
        var wrapped = next
        if (wrapped > limit) wrapped = 0
        if (wrapped < 0) wrapped = limit

        if (place === "h") control.hours = wrapped
        else if (place === "m") control.minutes = wrapped
        else control.seconds = wrapped

        control.edited()
    }

    function labelFor(place) {
        if (place === "h")
            return control.clock && !control.wide ? "HOUR" : "HOURS"
        if (place === "m")
            return "MIN"
        return "SEC"
    }

    implicitWidth: layout.implicitWidth + 20
    implicitHeight: 72
    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.textBase, 0.07)
    border.width: Theme.borderWidth
    border.color: Theme.alpha(Theme.textBase, 0.12)

    component Arrow: Item {
        property bool up: true
        signal pressed()

        width: 26
        height: 14

        Text {
            anchors.centerIn: parent
            text: parent.up ? "\u25B2" : "\u25BC"
            color: arrowArea.containsMouse ? Theme.accentText
                                           : Theme.alpha(Theme.textBase, 0.35)
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.pressed()

            // Held down, it keeps going
            onPressAndHold: repeat.start()
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }

        Timer {
            id: repeat
            interval: 90
            repeat: true
            onTriggered: parent.pressed()
        }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: control.places

            delegate: ColumnLayout {
                id: column
                required property var modelData
                required property int index

                spacing: 2

                Arrow {
                    Layout.alignment: Qt.AlignHCenter
                    up: true
                    onPressed: control.apply(column.modelData,
                        control.valueFor(column.modelData) + 1)
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 26
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.textBase, 0.10)

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var raw = control.valueFor(column.modelData)
                            if (column.modelData === "h" && control.clock
                                    && !control.wide) {
                                var shown = raw % 12
                                return shown === 0 ? "12" : String(shown)
                            }
                            return control.pad(raw)
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: 700
                    }

                    WheelHandler {
                        onWheel: (event) => control.apply(column.modelData,
                            control.valueFor(column.modelData)
                                + (event.angleDelta.y > 0 ? 1 : -1))
                    }
                }

                Arrow {
                    Layout.alignment: Qt.AlignHCenter
                    up: false
                    onPressed: control.apply(column.modelData,
                        control.valueFor(column.modelData) - 1)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: control.labelFor(column.modelData)
                    color: Theme.textMute
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: 700
                    font.letterSpacing: 0.6
                }
            }
        }

        // Which half of the day the alarm is in
        ColumnLayout {
            visible: control.clock && !control.wide
            spacing: 2

            Item { Layout.preferredHeight: 14; Layout.preferredWidth: 1 }

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 26
                radius: Theme.radiusSmall
                color: meridiemArea.containsMouse
                    ? Theme.alpha(Theme.accent, 0.30)
                    : Theme.alpha(Theme.accent, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: control.hours < 12 ? "AM" : "PM"
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: 700
                }

                MouseArea {
                    id: meridiemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        control.hours = control.hours < 12
                            ? control.hours + 12 : control.hours - 12
                        control.edited()
                    }
                }
            }

            Item { Layout.preferredHeight: 14; Layout.preferredWidth: 1 }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "HALF"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: 700
                font.letterSpacing: 0.6
            }
        }

        // In 24 hour mode there is no half to choose, so say so instead
        ColumnLayout {
            visible: control.clock && control.wide
            spacing: 2

            Item { Layout.preferredHeight: 14; Layout.preferredWidth: 1 }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 26
                verticalAlignment: Text.AlignVCenter
                text: "24h"
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: 700
            }
        }
    }
}
