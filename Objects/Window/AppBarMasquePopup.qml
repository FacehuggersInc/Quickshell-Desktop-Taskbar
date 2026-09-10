import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: masquePopup
    implicitHeight: masqueColumn.implicitHeight + 16
    implicitWidth: Math.max(masqueColumn.implicitWidth + 32, 240)
    sidePadding: 0
    fadingEffectMax: 1.0
    scrollingEffect: false

    // Set by AppBar before opening
    property var contextTarget: null
    signal masqueSelected(string targetClass, string masqueUnderName)

    content: ColumnLayout {
        id: masqueColumn
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 6
            Layout.topMargin: 6
            Layout.bottomMargin: 2

            Text {
                text: "Masque under:"
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
                onClicked: masquePopup.forceClose()
            }
        }

        Repeater {
            model: root.settings.launchers
            delegate: RoundButton {
                required property var modelData
                visible: masquePopup.contextTarget
                    ? modelData.name !== masquePopup.contextTarget.name
                    : true
                Layout.fillWidth: true
                padding: 6
                horizontalPadding: 16

                contentItem: RowLayout {
                    spacing: 8
                    Image {
                        source: modelData.icon && modelData.icon !== "*"
                            ? modelData.icon
                            : root.iconSource("open_app")
                        width: 20; height: 20
                        sourceSize.width: 20; sourceSize.height: 20
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    Text {
                        text: modelData.nickname !== modelData.name
                            ? modelData.nickname + "  (" + modelData.name + ")"
                            : modelData.name
                        font.family: root.settings.fontFamily
                        font.pixelSize: 13
                        font.weight: 500
                        color: root.theme.text
                        Layout.fillWidth: true
                    }
                }
                background: Rectangle {
                    radius: 6
                    color: masqueHov.hovered ? root.theme.primary : "transparent"
                    opacity: masqueHov.hovered ? 0.18 : 1
                }
                HoverHandler { id: masqueHov; cursorShape: Qt.PointingHandCursor }
                onClicked: {
                    if (masquePopup.contextTarget)
                        masquePopup.masqueSelected(masquePopup.contextTarget.name, modelData.name)
                    masquePopup.forceClose()
                }
            }
        }
    }
}