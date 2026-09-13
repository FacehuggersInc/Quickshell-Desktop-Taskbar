import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

// The week, with today marked. Split out of the date widget so it can be placed
// on its own, or dropped entirely.
Item {
    id: weekWidget

    readonly property var dayLetters: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var dayNames: [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"
    ]

    property int weekday: 0

    implicitWidth: strip.implicitWidth
    implicitHeight: Math.max(24, strip.implicitHeight)

    function tick() {
        weekWidget.weekday = new Date().getDay()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weekWidget.tick()
    }

    Component.onCompleted: weekWidget.tick()

    Row {
        id: strip
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: 7

            delegate: Text {
                required property int index

                readonly property bool today: index === weekWidget.weekday

                text: weekWidget.dayLetters[index]
                color: today ? Theme.accentText
                             : Theme.alpha(Theme.textBase, 0.35)
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: today ? 800 : 600

                Behavior on color { ColorAnimation { duration: Theme.durNormal } }
            }
        }
    }

    Tooltip {
        id: weekTip
        text: weekWidget.dayNames[weekWidget.weekday]
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) weekTip.showAt(point)
            else weekTip.hide()
        }
    }
}
