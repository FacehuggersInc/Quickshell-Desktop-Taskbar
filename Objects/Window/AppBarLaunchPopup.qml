import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: launchPopup
    implicitHeight: 45
    implicitWidth: 575
    sidePadding: 0
    fadingEffectMax: 1.0
    requireFocusGrab: true

    property var contextIcon: null

    function setAndOpen(launching, icon) {
        launchName.text = launching
        launchIcon.source = icon || ""
        launchPopup.forceOpen(appBarWidget)
        launchPopupTimer.running = true
    }

    Timer {
        id: launchPopupTimer
        interval: 1500
        onTriggered: launchPopup.forceClose()
    }

    content: RowLayout {
        anchors.fill: parent
        anchors.topMargin: 8
        spacing: 2

        Image {
            id: launchIcon
            source: ""
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            fillMode: Image.PreserveAspectFit
        }

        Text {
            id: launchName
            Layout.fillWidth: true
            color: root.theme.text
            font.family: root.settings.fontFamily
            font.weight: 500
            font.pixelSize: 20
        }
    }
}