import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// The card that holds a set of fields and one action. Used for every "add
// something" form so they share a shape instead of each being a different row.
Rectangle {
    default property alias fields: holder.data

    property string title: ""
    property string note: ""
    property string action: "Add"
    property bool ready: true
    signal submitted()

    Layout.fillWidth: true
    Layout.preferredHeight: holder.childrenRect.height + header.height + 34

    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.scrimBase, 0.42)
    border.width: Theme.borderWidth
    border.color: Theme.alpha(Theme.textBase, 0.12)

    RowLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        height: 20
        spacing: 8

        Text {
            text: parent.parent.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.labelSize
            font.weight: 700
        }

        Text {
            Layout.fillWidth: true
            text: parent.parent.note
            elide: Text.ElideRight
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }

        ActionButton {
            label: parent.parent.action
            tone: "accent"
            enabled: parent.parent.ready
            onActivated: parent.parent.submitted()
        }
    }

    Row {
        id: holder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14
    }
}
