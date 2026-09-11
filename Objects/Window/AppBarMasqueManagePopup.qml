import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: masqueManagePopup
    implicitHeight: masqueManageColumn.implicitHeight + 16
    implicitWidth: Math.max(masqueManageColumn.implicitWidth + 32, 240)
    sidePadding: 0
    fadingEffectMax: 1.0
    scrollingEffect: false

    property var masques: []
    signal removeMasqueRequested(string className)

    content: ColumnLayout {
        id: masqueManageColumn
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 6
            Layout.topMargin: 6
            Layout.bottomMargin: 2

            Text {
                text: "Remove masque:"
                color: Theme.text
                opacity: 0.55
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: 600
                Layout.fillWidth: true
            }

            IconButton {
                iconName: "close"
                iconSize: 14
                color: Theme.text
                tooltipText: "Cancel"
                onClicked: masqueManagePopup.forceClose()
            }
        }

        Repeater {
            model: masqueManagePopup.masques
            delegate: RoundButton {
                required property var modelData
                Layout.fillWidth: true
                padding: 6
                horizontalPadding: 16

                contentItem: RowLayout {
                    spacing: 8
                    Icon {
    iconName: "masked"
    iconSize: 18
    color: Theme.accentIcon
    opacity: 0.7
}
                    Text {
                        text: modelData.className
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: 500
                        color: Theme.text
                        Layout.fillWidth: true
                    }
                    Icon {
    iconName: "close"
    iconSize: 14
    color: Theme.accentIcon
    opacity: 0.6
}
                }
                background: Rectangle {
                    radius: 6
                    color: manageHov.hovered ? Theme.danger : "transparent"
                    opacity: manageHov.hovered ? 0.18 : 1
                }
                HoverHandler { id: manageHov; cursorShape: Qt.PointingHandCursor }
                onClicked: {
                    masqueManagePopup.removeMasqueRequested(modelData.className)
                    masqueManagePopup.forceClose()
                }
            }
        }
    }
}