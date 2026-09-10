import QtQuick

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Widgets.Internal

Item {
    id: clock

    // "dots" or "text"
    readonly property string style: {
        var w = root.settings.widgets || {}
        return w.clockStyle === "dots" ? "dots" : "text"
    }

    readonly property bool hour24: {
        var w = root.settings.widgets || {}
        return w.clock24 === true
    }

    property string timeText: ""
    property string meridiem: ""

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    // The old clock spawned a python process every second just to format a
    // date. Qt already knows what time it is.
    function tick() {
        var now = new Date()
        var hours = now.getHours()

        if (clock.hour24) {
            clock.meridiem = ""
        } else {
            clock.meridiem = hours < 12 ? "AM" : "PM"
            hours = hours % 12
            if (hours === 0) hours = 12
        }

        var hh = clock.hour24 ? (hours < 10 ? "0" + hours : String(hours))
                              : String(hours)
        var mm = now.getMinutes() < 10 ? "0" + now.getMinutes()
                                       : String(now.getMinutes())
        clock.timeText = hh + ":" + mm
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.tick()
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        DotMatrix {
            anchors.verticalCenter: parent.verticalCenter
            visible: clock.style === "dots"
            text: clock.style === "dots" ? clock.timeText : ""
            dotSize: 2.5
            dotGap: 1.5
            charGap: 4
            onColor: Theme.accentText
            offColor: Theme.alpha(Theme.textBase, 0.07)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: clock.style === "text"
            text: clock.timeText
            color: Theme.text
            font.family: Theme.fontFamily
            font.weight: 600
            font.pixelSize: 17
        }

        // Meridiem follows whichever style the time is using, at a smaller
        // dot size so it stays subordinate to the digits
        DotMatrix {
            anchors.verticalCenter: parent.verticalCenter
            visible: clock.style === "dots" && clock.meridiem !== ""
            text: clock.style === "dots" ? clock.meridiem : ""
            dotSize: 1.5
            dotGap: 1
            charGap: 2
            shadowSpread: 1.5
            onColor: Theme.textDim
            offColor: Theme.alpha(Theme.textBase, 0.05)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: clock.style === "text" && clock.meridiem !== ""
            text: clock.meridiem
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.weight: 700
            font.pixelSize: 9
        }
    }
}
