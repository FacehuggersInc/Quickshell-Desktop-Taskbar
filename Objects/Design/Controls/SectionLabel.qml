import QtQuick

import qs.Objects.Theme

Item {
    id: label

    property string text: ""
    property string extra: ""

    // Kept from TextDivider, which this replaced — the audio popup appends the
    // active media source to its heading
    function setExtraText(value) {
        label.extra = value ? value : ""
    }

    implicitHeight: 26
    implicitWidth: parent ? parent.width : 200

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: label.extra !== ""
            ? label.text.toUpperCase() + "  ·  " + label.extra.toUpperCase()
            : label.text.toUpperCase()
        color: Theme.textMute
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: 700
        font.letterSpacing: 1.2
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.borderWidth
        color: Theme.border
    }
}
