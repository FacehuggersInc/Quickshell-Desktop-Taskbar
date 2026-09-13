import QtQuick

import qs.Objects.Design
import qs.Objects.Systems
import qs.Objects.Theme

// The date as a small calendar leaf: month above, day large beneath, and the
// week running alongside with today marked. Reads as a date at a glance rather
// than as a row of letters with a number next to it.
Item {
    id: dateWidget

    property int weekday: 0
    property int dayNumber: 1
    property string monthName: ""
    property string fullDate: ""

    // Something starting within the next half hour
    readonly property var imminent: CalendarSystem.imminent

    // "leaf" is the calendar page, "week" keeps the older strip
    readonly property string style: {
        var bump = root.settingsRevision
        var widgets = root.settings.widgets || ({})
        return widgets.dateStyle ? widgets.dateStyle : "leaf"
    }

    implicitWidth: content.implicitWidth
    implicitHeight: Math.max(26, content.implicitHeight)

    function tick() {
        var now = new Date()
        dateWidget.weekday = now.getDay()
        dateWidget.dayNumber = now.getDate()
        dateWidget.monthName = Qt.formatDateTime(now, "MMM").toUpperCase()
        dateWidget.fullDate = Qt.formatDateTime(now, "dddd d MMMM yyyy")
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: dateWidget.tick()
    }

    Component.onCompleted: dateWidget.tick()

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        // ## Leaf
        // A month band over the day number, the way a torn-off calendar page
        // reads. The band carries the accent so the widget has one anchor of
        // colour rather than colour spread through the letters.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: dateWidget.style === "leaf"
            width: 26
            height: 26

            // Square. A rounded base made it read as a button rather than as a
            // page torn off a calendar.
            radius: 0
            color: Theme.alpha(Theme.textBase, 0.08)
            border.width: Theme.borderWidth
            border.color: Theme.alpha(Theme.textBase, 0.12)
            clip: true

            Rectangle {
                id: band
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 9

                // Turns amber when an event is close, so the widget carries the
                // warning without needing a badge
                color: dateWidget.imminent
                    ? Theme.warn : Theme.alpha(Theme.accent, 0.85)

                Behavior on color { ColorAnimation { duration: Theme.durNormal } }

                Text {
                    anchors.centerIn: parent
                    text: dateWidget.monthName
                    color: Theme.onAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: 7
                    font.weight: 800
                    font.letterSpacing: 0.5
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: band.bottom
                anchors.topMargin: 1
                text: dateWidget.dayNumber
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: 700
            }
        }

        // ## Plain
        // The old arrangement, for anyone who preferred it
        Column {
            anchors.verticalCenter: parent.verticalCenter
            visible: dateWidget.style !== "leaf"
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dateWidget.monthName
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: 700
                font.letterSpacing: 0.6
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dateWidget.dayNumber
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: 700
            }
        }
    }

    Tooltip {
        id: dateTip
        text: dateWidget.imminent
            ? dateWidget.imminent.title
              + (dateWidget.imminent.time !== ""
                  ? " at " + dateWidget.imminent.time : "")
            : dateWidget.fullDate
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) dateTip.showAt(point)
            else dateTip.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.calendarWindow) root.calendarWindow.open()
        }
    }
}
