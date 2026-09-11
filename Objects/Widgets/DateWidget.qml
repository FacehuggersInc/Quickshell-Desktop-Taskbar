import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

Item {
    id: dateWidget

    // The week reads as seven marks with today filled, so the position in the
    // week is legible without reading anything
    readonly property var dayLetters: ["S", "M", "T", "W", "T", "F", "S"]

    property int weekday: 0
    property int dayNumber: 1
    property string monthName: ""

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    function tick() {
        var now = new Date()
        dateWidget.weekday = now.getDay()
        dateWidget.dayNumber = now.getDate()
        dateWidget.monthName = Qt.formatDateTime(now, "MMM").toUpperCase()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: dateWidget.tick()
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Row {
                spacing: 3

                Repeater {
                    model: 7

                    delegate: Text {
                        required property int index

                        readonly property bool today: index === dateWidget.weekday

                        text: dateWidget.dayLetters[index]
                        color: today ? Theme.accentText
                                     : Theme.alpha(Theme.textBase, 0.35)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: today ? 700 : 600

                        Behavior on color { ColorAnimation { duration: Theme.durNormal } }
                    }
                }
            }

            Text {
                text: dateWidget.monthName
                color: Theme.textMute
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: 700
                font.letterSpacing: 1.6
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: dateWidget.dayNumber
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: 700
        }
    }

    Tooltip {
        id: dateTooltip
        text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) dateTooltip.showAt(point)
            else dateTooltip.hide()
        }
    }
}
