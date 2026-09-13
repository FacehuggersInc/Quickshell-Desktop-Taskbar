import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// A reading with its recent history, drawn as dot columns in the same language
// as the clock and the network meter.
Rectangle {
    id: graph

    property string iconName: ""
    property string caption: ""
    property string value: ""
    property real level: 0
    property var history: []

    readonly property int rows: 5

    Layout.fillWidth: true
    Layout.minimumWidth: 150
    Layout.preferredHeight: 68

    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.textBase, 0.06)
    border.width: Theme.borderWidth
    border.color: Theme.alpha(Theme.textBase, 0.10)

    Icon {
        id: graphIcon
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.top: parent.top
        anchors.topMargin: 9
        visible: graph.iconName !== ""
        iconName: graph.iconName
        iconSize: 15
        color: Theme.accentIcon
    }

    Text {
        id: captionText
        anchors.left: graphIcon.visible ? graphIcon.right : parent.left
        anchors.leftMargin: 7
        anchors.verticalCenter: graphIcon.verticalCenter
        text: graph.caption
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.weight: 700
        font.letterSpacing: 0.8
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.verticalCenter: graphIcon.verticalCenter
        text: graph.value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.valueSize
        font.weight: 700
    }

    // Columns fill from the bottom, one dot per fifth
    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.bottomMargin: 9
        height: 26
        spacing: 2

        Repeater {
            model: graph.history

            delegate: Column {
                id: column
                required property var modelData
                required property int index

                readonly property int lit:
                    Math.round(Math.max(0, Math.min(1, modelData)) * graph.rows)

                readonly property bool newest: index === graph.history.length - 1

                spacing: 2

                Repeater {
                    model: graph.rows

                    delegate: Rectangle {
                        required property int index

                        // Drawn top down, so invert to fill from the bottom.
                        // Referenced by id rather than parent chains, which is
                        // ambiguous inside a Repeater delegate.
                        readonly property bool on: (graph.rows - index) <= column.lit

                        width: 4
                        height: 4
                        radius: 2
                        color: on
                            ? (column.newest ? Theme.accentText : Theme.accentIcon)
                            : Theme.alpha(Theme.textBase, 0.10)

                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                }
            }
        }
    }
}
