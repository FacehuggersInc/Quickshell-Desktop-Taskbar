import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
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
                color: root.theme.text
                opacity: 0.55
                font.family: root.settings.fontFamily
                font.pixelSize: 12
                font.weight: 600
                Layout.fillWidth: true
            }

            IconButton {
                iconName: "close"
                iconSize: 14
                color: root.theme.text
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
                    Image {
                        source: root.iconSource("masked")
                        width: 18; height: 18
                        sourceSize.width: 18; sourceSize.height: 18
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.7
                    }
                    Text {
                        text: modelData.className
                        font.family: root.settings.fontFamily
                        font.pixelSize: 13
                        font.weight: 500
                        color: root.theme.text
                        Layout.fillWidth: true
                    }
                    Image {
                        source: root.iconSource("close")
                        width: 14; height: 14
                        sourceSize.width: 14; sourceSize.height: 14
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.6
                    }
                }
                background: Rectangle {
                    radius: 6
                    color: manageHov.hovered ? "#e05555" : "transparent"
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