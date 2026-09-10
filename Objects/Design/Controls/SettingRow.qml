import QtQuick

import qs.Objects.Design
import qs.Objects.Theme

Item {
    id: row

    property string iconName: ""
    property string label: ""
    property string description: ""
    property bool enabled: true

    // Set when the control sits under the label rather than beside it
    property bool stacked: false

    default property alias content: holder.data

    implicitWidth: parent ? parent.width : 320
    implicitHeight: stacked
        ? Theme.rowHeight + holder.childrenRect.height
        : Math.max(Theme.rowHeight, holder.childrenRect.height + 12)

    opacity: enabled ? 1.0 : 0.45

    Icon {
        id: icon
        visible: row.iconName !== ""
        iconName: row.iconName !== "" ? row.iconName : "settings"
        iconSize: 18
        color: Theme.accentIcon
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: (Theme.rowHeight - height) / 2
    }

    Column {
        id: labels
        anchors.left: icon.visible ? icon.right : parent.left
        anchors.leftMargin: icon.visible ? Theme.gap : 0
        anchors.top: parent.top
        anchors.topMargin: row.description !== "" ? 6 : (Theme.rowHeight - labelText.height) / 2
        spacing: 1

        width: row.stacked
            ? row.width - (icon.visible ? 18 + Theme.gap : 0)
            : row.width - (icon.visible ? 18 + Theme.gap : 0) - holder.childrenRect.width - Theme.gap

        Text {
            id: labelText
            width: parent.width
            text: row.label
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.labelSize
            font.weight: 600
        }

        Text {
            width: parent.width
            visible: row.description !== ""
            text: row.description
            wrapMode: Text.WordWrap
            color: Theme.textMute
            font.family: Theme.fontFamily
            font.pixelSize: Theme.descSize
        }
    }

    Item {
        id: holder
        anchors.right: row.stacked ? undefined : parent.right
        anchors.left: row.stacked ? labels.left : undefined
        anchors.top: row.stacked ? labels.bottom : parent.top
        anchors.topMargin: row.stacked ? 8 : (Theme.rowHeight - childrenRect.height) / 2
        width: row.stacked ? labels.width : childrenRect.width
        height: childrenRect.height
    }
}
