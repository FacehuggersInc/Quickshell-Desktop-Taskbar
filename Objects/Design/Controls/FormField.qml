import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// One labelled slot in a composer. Every input sits in one of these, so a row
// of mixed controls reads as a set of fields rather than a pile of widgets.
ColumnLayout {
    default property alias field: holder.data

    property string caption: ""
    property string hint: ""

    spacing: 3

    Text {
        Layout.fillWidth: true
        text: caption.toUpperCase()
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.weight: 700
        font.letterSpacing: 0.8
    }

    Item {
        id: holder
        Layout.fillWidth: true
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    Text {
        Layout.fillWidth: true
        visible: hint !== ""
        text: hint
        elide: Text.ElideRight
        color: Theme.alpha(Theme.textBase, 0.35)
        font.family: Theme.fontFamily
        font.pixelSize: 9
    }
}
