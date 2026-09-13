import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// The shared chassis for quick panel controls. Every row is the same height,
// radius, border and icon box, so the only thing that differs between a slider,
// a segmented control and a shortcut is the body each one puts on the right.
//
// State is shown by fill, kind is shown by shape: a toggle fills when on, a
// slider fills proportionally, a shortcut never fills.
Rectangle {
    id: panelRow

    default property alias body: holder.data

    property string iconName: ""

    // An application icon path, for rows describing a real app rather than a
    // shell concept
    property string iconSource: ""

    property string label: ""
    property string detail: ""
    property real fillFraction: 0
    property bool active: false

    // Rows that go somewhere. The chevron and the click target belong to the
    // row itself — passing a MouseArea in as the body only ever filled the
    // small slot on the right, which is why those rows did nothing.
    property bool navigates: false
    signal activated()

    readonly property int rowHeight: 52

    Layout.fillWidth: true
    Layout.preferredHeight: panelRow.rowHeight

    radius: Theme.radiusSmall
    color: panelRow.active ? Theme.alpha(Theme.accent, 0.18)
        : (rowArea.containsMouse ? Theme.alpha(Theme.accent, 0.10)
                                 : Theme.alpha(Theme.scrimBase, 0.35))
    border.width: Theme.borderWidth
    border.color: panelRow.active ? Theme.accentLine
                                  : Theme.alpha(Theme.textBase, 0.10)
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    // Proportional fill, for controls whose value is a level
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, panelRow.fillFraction))
        radius: parent.radius
        color: Theme.alpha(Theme.accent, 0.22)
        visible: panelRow.fillFraction > 0
    }

    Rectangle {
        id: iconBox
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: Theme.radiusSmall
        color: panelRow.active ? Theme.alpha(Theme.accent, 0.30)
                               : Theme.alpha(Theme.textBase, 0.08)
        visible: panelRow.iconName !== "" || panelRow.iconSource !== ""

        Icon {
            anchors.centerIn: parent
            visible: panelRow.iconSource === ""
            iconName: panelRow.iconName
            iconSize: 16
            color: panelRow.active ? Theme.accentIcon : Theme.textDim
        }

        Image {
            anchors.fill: parent
            anchors.margins: 4
            visible: panelRow.iconSource !== ""
            source: panelRow.iconSource
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 48
            sourceSize.height: 48
            smooth: true
            asynchronous: true
        }
    }

    Column {
        id: labels
        anchors.left: iconBox.visible ? iconBox.right : parent.left
        anchors.leftMargin: 10
        anchors.right: holder.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: panelRow.label
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.labelSize
            font.weight: 600
        }

        Text {
            width: parent.width
            visible: panelRow.detail !== ""
            text: panelRow.detail
            elide: Text.ElideRight
            color: panelRow.active ? Theme.accentText : Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }
    }

    Item {
        id: holder
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: panelRow.navigates
        text: "\u203A"
        color: rowArea.containsMouse ? Theme.accentText : Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: 17
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        enabled: panelRow.navigates
        cursorShape: Qt.PointingHandCursor
        onClicked: panelRow.activated()
    }
}
